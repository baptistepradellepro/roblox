--[[
	Simulation de parties complètes avec le VRAI code serveur : `lune run tests/sim.luau`
	3 joueurs arrivent, achètent, volent, se font rattraper, la nuit tombe, rebirth,
	cadeau du jour, achats Robux, déconnexion / reconnexion avec la sauvegarde...
]]

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Fake = require("./fakeroblox")
local Sched = Fake.Sched
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

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
Config.Products.Spin1 = 1001
Config.GamePasses.DoubleCoins = 555
Config.GamePasses.WeaponBroom = 556
-- ces articles restent "sans ID" pour tester le mode gratuit de Studio et "Bientôt"
Config.Products.Spin5 = 0
Config.Products.MonsterGloutrouille = 0
Config.Products.MonsterBat = 0
Config.Products.MonsterSpider = 0
Config.GamePasses.WeaponHammer = 0
Config.GamePasses.WeaponVacuum = 0
Config.Badges.Welcome = 9000
Config.Badges.FirstSteal = 9001
Config.Badges.FirstMythic = 9002
Config.Badges.FirstSecret = 9003

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
local Weapons = Fake.require("ReplicatedStorage.Shared.Weapons")

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

-- Le serveur déplace un joueur (comme l'ascenseur) : l'anti-triche ne compte pas ce saut
local function place(player, position: Vector3)
	Fake.require("ServerScriptService.Services.Guard").teleport(player, player.Character, CFrame.new(position))
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

section("Revenus et récolte sur les plaques")
local before = aData.Coins
Sched.advance(10)
local gained = aData.Coins - before
check(gained >= 9 and gained <= 11, "1 pièce/s de revenu de base arrive directement (gagné : " .. gained .. ")")
check(aData.Stored["1"] >= 9 and aData.Stored["1"] <= 14, "le Drap Mou remplit son socle (" .. tostring(aData.Stored["1"]) .. ")")
check(BaseService.getBase(alice).Pedestals[1]:GetAttribute("Stored") >= 9, "pièces affichées au-dessus de la plaque")
check(alice:GetAttribute("Stored") >= 9, "total à récupérer affiché dans le HUD")
check(alice:GetAttribute("Coins") == math.floor(aData.Coins), "attribut Coins à jour")
check(alice:GetAttribute("Income") == 2, "revenu affiché = 2/s")
local pad1 = BaseService.getBase(alice).Pedestals[1]:FindFirstChild("CollectPad")
local beforeCollect = aData.Coins
pad1.Touched:Fire(bob.Character.HumanoidRootPart)
check(aData.Coins == beforeCollect and aData.Stored["1"] >= 9, "un autre joueur ne peut pas récolter")
pad1.Touched:Fire(alice.Character.HumanoidRootPart)
check(aData.Coins >= beforeCollect + 9 and aData.Stored["1"] < 1, "Alice récolte ses pièces en passant sur la plaque")
check(alice:GetAttribute("HasCollected") == true, "tutoriel : récolte notée")

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
place(alice, pathPosition(target))
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
place(alice, pathPosition(other) + Vector3.new(0, 0, 60))
Fake.fire(alice, "BuyGhost", other.Name)
check(notified(alice, "TooFar", m) and other.Parent ~= nil, "achat refusé de trop loin")

-- anti-triche : juste après s'être téléporté tout seul, pas d'achat pendant 2 s
Sched.advance(1.2)
Fake.moveTo(alice, pathPosition(other))
Sched.advance(0.3)
m = mark()
Fake.fire(alice, "BuyGhost", other.Name)
check(notified(alice, "TooFar", m) and other.Parent ~= nil, "téléporté à côté d'un fantôme : achat refusé")
Sched.advance(2)
place(alice, pathPosition(other) + Vector3.new(0, 0, 60))
Sched.advance(0.3)

bData.Coins = 0
m = mark()
place(bob, pathPosition(other))
Fake.fire(bob, "BuyGhost", other.Name)
check(notified(bob, "NotEnoughCoins", m) and other.Parent ~= nil, "achat refusé sans argent")
Sched.advance(0.3)
m = mark()
Fake.fire(bob, "BuyGhost", 12345)
Sched.advance(0.3)
Fake.fire(bob, "BuyGhost", "inexistant")
check(notified(bob, "AlreadyGone", m), "uid invalide refusé proprement")

section("Variante Dorée")
GhostService.spawn("Caquetome#Gold")
local goldHolder = nil
for _, h in RS.PathGhosts:GetChildren() do
	if h:GetAttribute("GhostId") == "Caquetome#Gold" then
		goldHolder = h
	end
end
check(goldHolder ~= nil, "un Caquetôme Doré apparaît sur le chemin")
Sched.advance(0.3)
local coinsGold = aData.Coins
local incomeBefore = alice:GetAttribute("Income")
place(alice, pathPosition(goldHolder))
Fake.fire(alice, "BuyGhost", goldHolder.Name)
check(coinsGold - aData.Coins == GhostData.get("Caquetome").Price * 3, "le Doré coûte 3 fois plus")
check(alice:GetAttribute("Income") - incomeBefore == GhostData.get("Caquetome").Income * 3, "et rapporte 3 fois plus")
check(aData.Discovered.Caquetome == true, "il compte dans le Fantômédex")
local goldSlot
for key, id in aData.Slots do
	if id == "Caquetome#Gold" then
		goldSlot = tonumber(key)
	end
end
Sched.advance(0.4)
local beforeSell = aData.Coins
Fake.moveTo(alice, pedestalPos(alice, goldSlot))
Fake.fire(alice, "SellGhost", goldSlot)
local goldSale = math.floor(GhostData.get("Caquetome").Price * 3 * Config.SellRatio)
check(aData.Coins - beforeSell >= goldSale and aData.Coins - beforeSell <= goldSale + 60, "revendu au prix Doré (+ les pièces du socle)")
Sched.advance(0.4)

section("Vente")
local coinsBefore = aData.Coins
Fake.moveTo(alice, pedestalPos(alice, 2))
Fake.fire(alice, "SellGhost", 2)
check(aData.Slots["2"] == nil, "fantôme vendu")
local sale = math.floor(GhostData.get(boughtId).Price * Config.SellRatio)
check(aData.Coins >= coinsBefore + sale and aData.Coins <= coinsBefore + sale + GhostData.incomeOf(boughtId) * 8 + 1, "50 % du prix remboursé")
Sched.advance(0.4)
Fake.fire(alice, "SellGhost", 99)
Sched.advance(0.4)
Fake.fire(alice, "SellGhost", "1")
Sched.advance(0.4)
Fake.fire(alice, "SellGhost", 1.5)
check(aData.Slots["1"] ~= nil, "ventes invalides ignorées")

section("Étage 2 et ascenseur")
local base = BaseService.getBase(alice)
local floor2 = base.Model:FindFirstChild("Floor2")
local platform = floor2:FindFirstChild("Floor2Platform")
check(platform.Transparency == 1 and not platform.CanCollide, "étage 2 caché au départ")
check(base.Pedestals[11]:GetAttribute("Unlocked") == false, "socles de l'étage fermés")
local savedSlots = table.clone(aData.Slots)
for slot = 1, Config.PedestalsPerFloor do
	aData.Slots[tostring(slot)] = aData.Slots[tostring(slot)] or "DrapMou"
end
local fullHolder = RS.PathGhosts:GetChildren()[1]
check(fullHolder ~= nil, "un fantôme sur le chemin pour tester la base pleine")
if fullHolder then
	Sched.advance(0.3)
	m = mark()
	place(alice, pathPosition(fullHolder))
	Fake.fire(alice, "BuyGhost", fullHolder.Name)
	check(notified(alice, "NoFreePedestalFloor", m) and fullHolder.Parent ~= nil, "base pleine : le jeu propose l'étage 2")
end
for key in aData.Slots do
	if savedSlots[key] == nil then
		aData.Slots[key] = nil
	end
end
local upPad = base.Model:FindFirstChild("UpPad")
Fake.moveTo(alice, upPad.Position + Vector3.new(0, 3, 0))
upPad.Touched:Fire(alice.Character.HumanoidRootPart)
check(Fake.position(alice).Y < base.Origin.Position.Y + 8, "l'ascenseur ne marche pas sans l'étage")
aData.Coins = 100
m = mark()
Fake.fire(alice, "BuyFloor")
check(notified(alice, "NotEnoughCoins", m) and (aData.Floors or 1) == 1, "étage refusé sans argent")
Sched.advance(1.1)
aData.Coins = Config.FloorPrice + 500
m = mark()
Fake.fire(alice, "BuyFloor")
check(aData.Floors == 2 and notified(alice, "FloorBought", m), "étage 2 acheté")
check(aData.Coins == 500, "prix de l'étage retiré")
check(base.Model:GetAttribute("Floors") == 2, "l'étage est annoncé aux joueurs")
check(platform.Transparency == 0 and platform.CanCollide, "le sol de l'étage apparaît")
check(base.Pedestals[11]:GetAttribute("Unlocked") == true and base.Pedestals[20]:GetAttribute("Unlocked") == true, "10 socles de plus")
check(base.Pedestals[11]:FindFirstChild("CollectPad").CanTouch == true, "plaques de l'étage actives")
Sched.advance(1.1)
upPad.Touched:Fire(alice.Character.HumanoidRootPart)
check(Fake.position(alice).Y > base.Origin.Position.Y + 14, "l'ascenseur monte à l'étage")
local downPad = floor2:FindFirstChild("DownPad")
Sched.advance(1.1)
downPad.Touched:Fire(alice.Character.HumanoidRootPart)
check(Fake.position(alice).Y < base.Origin.Position.Y + 8, "et redescend")
check(BaseService.isInside(base, base.Origin.Position + Vector3.new(0, 17, 0)), "l'étage compte comme dans la base")
Sched.advance(1.1)
Fake.fire(alice, "BuyFloor")
check(aData.Coins >= 500, "on ne paie pas deux fois l'étage")
Fake.moveTo(alice, baseCenter(alice))

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

section("Classement des voleurs")
local LeaderboardService = Fake.require("ServerScriptService.Services.LeaderboardService")
LeaderboardService.refresh()
local boardRaw = RS:GetAttribute("LeaderboardData")
local board = serde.decode("json", boardRaw)
check(#board >= 1 and board[1].Name == "Bob" and board[1].Value == 1, "Bob en tête du classement avec 1 vol")
check(RS:GetAttribute("LeaderboardResetAt") > workspace:GetServerTimeNow(), "date de remise à zéro dans le futur")
check(LeaderboardService.weekNumber(1790812800 + 4 * 86400) ~= LeaderboardService.weekNumber(1790812800 + 3 * 86400), "nouvelle semaine le lundi")
check(LeaderboardService.weekNumber(1790812800 + 86400) == LeaderboardService.weekNumber(1790812800 + 3 * 86400 - 1), "même semaine du jeudi au dimanche")
Fake.orderedStoreBroken = true
LeaderboardService.refresh()
board = serde.decode("json", RS:GetAttribute("LeaderboardData"))
check(#board >= 1 and board[1].Name == "Bob", "sans accès aux API : classement de la partie en cours")
Fake.orderedStoreBroken = false

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
Sched.advance(Weapons.ById.Batte.Stun + 0.1)
check(bob.Character.Humanoid.WalkSpeed == Config.NormalWalkSpeed, "Bob n'est plus étourdi")
m = mark()
Fake.fire(chloe, "Bonk")
check(not notified(chloe, "BonkHit", m), "pas de Pouet sans voleur")

section("Batte et armes")
local WeaponService = Fake.require("ServerScriptService.Services.WeaponService")
local function hasTool(player, id: string): boolean
	for _, container in { player:FindFirstChild("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:GetAttribute("WeaponId") == id then
					return true
				end
			end
		end
	end
	return false
end
check(hasTool(alice, "Batte") and hasTool(bob, "Batte") and hasTool(chloe, "Batte"), "tout le monde a sa batte")
check(not hasTool(chloe, "MarteauPouet"), "pas d'arme payante sans Game Pass")
steal(bob, alice, slot)
check(bob:GetAttribute("CarryGhost") == "Caquetome", "encore un vol")
place(bob, Vector3.new(0, 3, 12))
Fake.moveTo(chloe, Vector3.new(10.5, 3, 12))
Sched.advance(2)
Fake.fire(chloe, "Bonk", "MarteauPouet")
check(bob:GetAttribute("CarryGhost") ~= nil, "arme pas achetée : rien ne se passe")
Sched.advance(0.3)
Fake.fire(chloe, "Bonk", "Batte")
check(bob:GetAttribute("CarryGhost") ~= nil, "trop loin pour la batte (portée " .. Weapons.ById.Batte.Range .. ")")
chloe:SetAttribute("Weapon_MarteauPouet", true)
WeaponService.giveTools(chloe)
check(hasTool(chloe, "MarteauPouet"), "le Marteau Pouet Géant arrive dans le sac")
WeaponService.giveTools(chloe)
local hammers = 0
for _, child in chloe.Backpack:GetChildren() do
	if child:GetAttribute("WeaponId") == "MarteauPouet" then
		hammers += 1
	end
end
check(hammers == 1, "pas de doublon dans le sac")
Sched.advance(2)
m = mark()
Fake.fire(chloe, "Bonk", "MarteauPouet")
check(bob:GetAttribute("CarryGhost") == nil and notified(chloe, "BonkHit", m), "le marteau porte plus loin que la batte")
check(bob.Character.Humanoid.WalkSpeed == 4, "Bob est étourdi plus longtemps")
Sched.advance(Weapons.ById.MarteauPouet.Stun + 0.1)
-- un intrus dans ma base se fait chasser
Fake.moveTo(alice, baseCenter(alice))
Fake.moveTo(bob, baseCenter(alice) + Vector3.new(3, 0, 0))
Sched.advance(2)
m = mark()
Fake.fire(alice, "Bonk")
check(not BaseService.isInside(BaseService.getBase(alice), Fake.position(bob)), "Bob est chassé de la base d'Alice")
check(notified(bob, "PushedOut", m), "message pour Bob")
Sched.advance(Weapons.ById.Batte.Stun + 0.1)
-- on ne frappe pas en portant un fantôme volé : deux voleurs côte à côte
local otherSlot = GhostService.giveGhost(alice, "DrapMou")
steal(bob, alice, slot)
steal(chloe, alice, otherSlot)
check(bob:GetAttribute("CarryGhost") ~= nil and chloe:GetAttribute("CarryGhost") ~= nil, "deux voleurs en même temps")
Fake.moveTo(bob, Vector3.new(0, 3, -12))
Fake.moveTo(chloe, Vector3.new(2, 3, -12))
Fake.fire(bob, "Bonk")
check(chloe:GetAttribute("CarryGhost") ~= nil, "un voleur qui porte un fantôme ne peut pas frapper")
StealService.failCarry(bob, "Timeout")
StealService.failCarry(chloe, "Timeout")
Sched.advance(1)
-- la batte revient après une réapparition
bob:LoadCharacter()
Sched.advance(0.5)
check(hasTool(bob, "Batte"), "la batte revient après une réapparition")

section("Pièges")
local Traps = Fake.require("ReplicatedStorage.Shared.Traps")
local TrapService = Fake.require("ServerScriptService.Services.TrapService")
local aliceBase = BaseService.getBase(alice)
local function trapModel(id: string)
	return aliceBase.Model.Traps:FindFirstChild("Trap_" .. id)
end
local function trapPos(id: string): Vector3
	return aliceBase.Origin:PointToWorldSpace(Traps.ById[id].Position)
end
local function lookVisible(id: string): boolean
	for _, d in trapModel(id):GetDescendants() do
		if d:GetAttribute("TrapLook") and d.Transparency < 1 then
			return true
		end
	end
	return false
end
check(trapModel("Banana") and trapModel("Web") and trapModel("Alarm"), "3 emplacements de pièges dans la base")
check(not lookVisible("Banana") and trapModel("Banana").Spot.Transparency < 1, "piège caché, emplacement visible")
aData.Coins = 1_000_000
Fake.moveTo(alice, baseCenter(bob))
Sched.advance(0.6)
Fake.fire(alice, "BuyTrap", "Banana")
check(not (aData.Traps or {}).Banana, "on n'achète pas un piège de loin")
Fake.moveTo(alice, trapPos("Banana") + Vector3.new(0, 3, 2))
aData.Coins = 100
Sched.advance(0.6)
m = mark()
Fake.fire(alice, "BuyTrap", "Banana")
check(notified(alice, "NotEnoughCoins", m) and not aData.Traps.Banana, "pas assez de pièces")
aData.Coins = 1_000_000
for _, id in { "Banana", "Web", "Alarm" } do
	Fake.moveTo(alice, trapPos(id) + Vector3.new(0, 3, 2))
	Sched.advance(0.6)
	Fake.fire(alice, "BuyTrap", id)
end
check(aData.Traps.Banana and aData.Traps.Web and aData.Traps.Alarm, "3 pièges achetés")
local afterTraps = 1_000_000 - Config.Traps.Banana.Price - Config.Traps.Web.Price - Config.Traps.Alarm.Price
check(aData.Coins >= afterTraps and aData.Coins < afterTraps + 100, "prix des pièges retirés (" .. math.floor(aData.Coins) .. ")")
check(lookVisible("Banana") and lookVisible("Web") and lookVisible("Alarm"), "les pièges apparaissent")
check(trapModel("Banana").Spot.Transparency == 1 and trapModel("Banana"):GetAttribute("Owned") == true, "l'emplacement disparaît")
Sched.advance(0.6)
m = mark()
Fake.fire(alice, "BuyTrap", "Alarm")
check(notified(alice, "TrapOwned", m), "pas deux fois le même piège")
-- le propriétaire ne déclenche jamais ses pièges
Fake.moveTo(alice, trapPos("Banana") + Vector3.new(0, 3, 0))
Sched.advance(0.5)
Fake.moveTo(alice, trapPos("Web") + Vector3.new(0, 3, 0))
Sched.advance(0.5)
check(alice.Character.Humanoid.WalkSpeed == Config.NormalWalkSpeed and lookVisible("Banana"), "Alice ne se fait pas piéger chez elle")
park(alice, 150, 70)
-- Bob entre : l'alarme prévient Alice, même loin
m = mark()
steal(bob, alice, slot)
check(notified(alice, "AlarmOwner", m), "l'alarme prévient Alice")
check(aliceBase.Model:GetAttribute("AlarmUntil") > workspace:GetServerTimeNow(), "la sirène sonne")
check(notified(bob, "AlarmIntruder", m), "Bob sait que l'alarme sonne")
check(bob:GetAttribute("CarryGhost") ~= nil, "Bob vole quand même")
-- en repartant, il glisse sur la banane
m = mark()
Fake.moveTo(bob, trapPos("Banana") + Vector3.new(0.8, 3, 0))
Sched.advance(0.3)
check(bob:GetAttribute("CarryGhost") == nil, "Bob glisse sur la banane et lâche le fantôme")
check(notified(bob, "TrapSlipped", m) and notified(alice, "TrapCaught", m), "messages du piège")
check(bob.Character.Humanoid.WalkSpeed == 4, "Bob est étourdi")
check(not lookVisible("Banana"), "la banane a servi")
Sched.advance(Config.Traps.Banana.Stun + 0.2)
check(bob.Character.Humanoid.WalkSpeed == Config.NormalWalkSpeed, "Bob se relève")
Fake.moveTo(bob, trapPos("Banana") + Vector3.new(0.8, 3, 0))
Sched.advance(0.3)
check(bob.Character.Humanoid.WalkSpeed == Config.NormalWalkSpeed, "la banane ne resert pas tout de suite")
-- la toile ralentit
m = mark()
Fake.moveTo(bob, trapPos("Web") + Vector3.new(3, 3, 0.5))
Sched.advance(0.3)
check(bob.Character.Humanoid.WalkSpeed == Config.Traps.Web.Speed and notified(bob, "TrapWebbed", m), "la toile ralentit Bob")
park(bob, -150, 70)
Sched.advance(Config.Traps.Web.SlowTime + 0.2)
check(bob.Character.Humanoid.WalkSpeed == Config.NormalWalkSpeed, "plus ralenti après quelques secondes")
Sched.advance(Config.Traps.Banana.Cooldown)
check(lookVisible("Banana"), "la banane revient")
-- après un rebirth (réglage par défaut), on garde ses pièges
TrapService.onRebirth(alice)
check(aData.Traps.Banana and lookVisible("Banana"), "les pièges restent après un rebirth")

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

section("Anti-triche : livraison et vol à travers un mur")
Sched.advance(1)
steal(bob, alice, slot)
check(bob:GetAttribute("CarryGhost") ~= nil, "vol lancé")
Fake.moveTo(bob, baseCenter(bob))
Sched.advance(0.3)
check(bob:GetAttribute("CarryGhost") == nil, "téléporté chez lui : vol annulé")
check(aData.Slots[tostring(slot)] == "Caquetome", "le fantôme n'a pas été livré")
Sched.advance(1)
-- le serveur le pose chez lui (sans tricher) : il faut quand même être sorti à pied
steal(bob, alice, slot)
place(bob, baseCenter(bob))
Sched.advance(1)
check(bob:GetAttribute("CarryGhost") ~= nil and aData.Slots[tostring(slot)] == "Caquetome", "pas de livraison sans sortir de la base volée")
StealService.failCarry(bob, "Timeout")
Sched.advance(1)
-- réseau mobile qui gèle 1 s puis rattrape d'un coup : ce n'est pas de la triche
steal(bob, alice, slot)
Sched.advance(1.2)
Fake.moveTo(bob, Fake.position(bob) + Vector3.new(0, 0, -12))
Sched.advance(0.3)
check(bob:GetAttribute("CarryGhost") ~= nil, "petit gel du réseau : le vol continue")
StealService.failCarry(bob, "Timeout")
Sched.advance(1)
-- à travers le mur : juste derrière le mur de côté, près d'un socle
local MapBuilder = Fake.require("ServerScriptService.Services.MapBuilder")
local aliceOrigin = BaseService.getBase(alice).Origin
local spot = MapBuilder.PEDESTAL_SPOTS[slot]
m = mark()
Fake.moveTo(bob, aliceOrigin:PointToWorldSpace(Vector3.new(spot.Side * (MapBuilder.BASE_WIDTH / 2 + 1), 3, spot.Z)))
Fake.fire(bob, "StealBegin", BaseService.getBase(alice).Index, slot)
Sched.advance(1.6)
Fake.fire(bob, "Steal", BaseService.getBase(alice).Index, slot)
check(bob:GetAttribute("CarryGhost") == nil and notified(bob, "TooFar", m), "pas de vol à travers le mur")
-- marche un peu trop vite pendant plusieurs secondes : repéré
steal(bob, alice, slot)
check(bob:GetAttribute("CarryGhost") ~= nil, "vol lancé")
Fake.walk(bob, Fake.position(bob) + Vector3.new(0, 0, -60), Config.CarrierWalkSpeed * 1.6)
check(bob:GetAttribute("CarryGhost") == nil, "trop rapide : vol annulé")
Sched.advance(1)

section("Trop lent (45 s)")
Sched.advance(1)
steal(bob, alice, slot)
check(bob:GetAttribute("CarryGhost") ~= nil, "vol lancé")
place(bob, Vector3.new(40, 3, 12))
m = mark()
Sched.advance(Config.StealTimeout + 1)
check(bob:GetAttribute("CarryGhost") == nil, "délai dépassé : vol annulé")
check(notified(bob, "StealFailTimeout", m), "message 'trop lent'")

section("Verrou de base")
Fake.moveTo(bob, pedestalPos(alice, slot))
park(alice, 150, 70)
m = mark()
Fake.fire(alice, "RequestLock")
check(notified(alice, "LockGoToButton", m) and not BaseService.isLocked(BaseService.getBase(alice)), "on ne verrouille pas de loin")
Fake.moveTo(alice, baseCenter(alice))
Sched.advance(0.6)
m = mark()
Fake.fire(alice, "RequestLock")
check(notified(alice, "LockGoToButton", m), "ni depuis le milieu de sa base : seulement au bouton")
local lockButton = BaseService.getBase(alice).Model:FindFirstChild("LockButton")
Fake.moveTo(alice, lockButton.Position + Vector3.new(0, 3, -2))
Sched.advance(0.6)
m = mark()
Fake.fire(alice, "RequestLock")
check(notified(alice, "LockOn", m), "base verrouillée au bouton du fond")
local barrierModel = BaseService.getBase(alice).Model:FindFirstChild("Barrier")
check(barrierModel ~= nil, "la barrière est là")
check(barrierModel and barrierModel:FindFirstChild("Collider") and barrierModel.Collider.CanCollide, "elle bloque l'entrée")
local bars = 0
for _, d in barrierModel:GetChildren() do
	if d.Name == "Bar" then
		bars += 1
	end
end
check(bars >= 5, "barreaux rouges et blancs (" .. bars .. ")")
local PhysicsService = Fake.game:GetService("PhysicsService")
local aliceIndex = BaseService.getBase(alice).Index
local gateName, ownerName = "Gate" .. aliceIndex, "Owner" .. aliceIndex
check(barrierModel.Collider.CollisionGroup == gateName, "la barrière a son groupe de collision")
check(alice.Character.HumanoidRootPart.CollisionGroup == ownerName, "Alice est dans le groupe du propriétaire")
check(not PhysicsService:CollisionGroupsAreCollidable(gateName, ownerName), "Alice traverse sa barrière (géré par le serveur)")
local bobGroup = bob.Character.HumanoidRootPart.CollisionGroup
check(bobGroup == "Owner" .. BaseService.getBase(bob).Index, "Bob est dans le groupe de sa propre base")
check(PhysicsService:CollisionGroupsAreCollidable(gateName, bobGroup), "la barrière d'Alice bloque Bob")
check(PhysicsService:CollisionGroupsAreCollidable(gateName, "Default"), "et les joueurs sans base")
check(PhysicsService:CollisionGroupsAreCollidable("Gate" .. BaseService.getBase(bob).Index, ownerName), "Alice ne traverse pas la barrière de Bob")
local hat = Fake.Instance.new("Part")
hat.Name = "Handle"
hat.Parent = alice.Character
check(hat.CollisionGroup == ownerName, "un accessoire ajouté après suit le même groupe")
hat:Destroy()
check(Config.LockDuration == 45, "le verrou dure 45 s")
Sched.advance(0.5)
check(not BaseService.isInside(BaseService.getBase(alice), Fake.position(bob)), "Bob est renvoyé dehors")
m = mark()
steal(bob, alice, slot)
check(notified(bob, "BaseIsLocked", m), "vol impossible pendant le verrou")
Sched.advance(Config.LockDuration - 3)
check(BaseService.getBase(alice).Model:FindFirstChild("Barrier") ~= nil, "la barrière tient presque jusqu'au bout")
Sched.advance(4)
check(BaseService.getBase(alice).Model:FindFirstChild("Barrier") == nil, "la barrière disparaît après 45 s")
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
local startAnnounced = announced("NightStart", m) or announced("NightStartFog", m) or announced("NightStartCandy", m) or announced("NightStartSuper", m)
check(announced("NightSoon", m) and startAnnounced, "annonces de la nuit (" .. tostring(RS:GetAttribute("NightTheme")) .. ")")
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

section("Calendrier : Super Nuit et week-end x2")
local NightService = Fake.require("ServerScriptService.Services.NightService")
-- samedi 3 octobre 2026
local SATURDAY = 1790812800 + 2 * 86400
check(NightService.isSuperTime(SATURDAY + 17.5 * 3600), "samedi 17h30 UTC = Super Nuit")
check(not NightService.isSuperTime(SATURDAY + 18 * 3600), "samedi 18h UTC : c'est fini")
check(not NightService.isSuperTime(SATURDAY - 86400 + 17.5 * 3600), "vendredi : pas de Super Nuit")
local FRIDAY = SATURDAY - 86400
check(EconomyService.isWeekendBoost(FRIDAY + 18 * 3600), "vendredi 18h UTC : week-end x2")
check(not EconomyService.isWeekendBoost(FRIDAY + 16 * 3600), "vendredi 16h UTC : pas encore")
check(EconomyService.isWeekendBoost(SATURDAY + 12 * 3600), "samedi : x2")
check(EconomyService.isWeekendBoost(SATURDAY + 86400 + 22 * 3600), "dimanche 22h UTC : x2")
check(not EconomyService.isWeekendBoost(SATURDAY + 86400 + 23.5 * 3600), "dimanche 23h30 UTC : fini")
check(not EconomyService.isWeekendBoost(SATURDAY + 2 * 86400 + 12 * 3600), "lundi : normal")
local realWeekend = EconomyService.isWeekendBoost
local multNormal = alice:GetAttribute("Multiplier")
EconomyService.isWeekendBoost = function()
	return true
end
Sched.advance(1.1)
check(RS:GetAttribute("WeekendBoost") == true, "le week-end x2 est annoncé aux joueurs")
check(math.abs(alice:GetAttribute("Multiplier") - multNormal * 2) < 0.02, "revenus doublés le week-end")
EconomyService.isWeekendBoost = realWeekend
Sched.advance(1.1)
check(RS:GetAttribute("WeekendBoost") == false, "retour à la normale")

section("Nuit des Bonbons")
local MissionService = Fake.require("ServerScriptService.Services.MissionService")
cData.Missions.List = { { Id = "NightOutside", Tier = "medium", Target = 3, Progress = 0, Done = false } }
local savedThemes = Config.NightThemes
Config.NightThemes = { Classic = 0, Fog = 0, Candy = 1 }
Sched.advance(RS:GetAttribute("NextNightAt") - workspace:GetServerTimeNow() + 1)
check(RS:GetAttribute("NightTheme") == "Candy", "thème : Bonbons")
local candy = workspace:FindFirstChild("CandyCoins")
check(candy ~= nil and #candy:GetChildren() == Config.CandyCoinCount, "24 pièces posées sur le chemin")
local inBase = false
for _, coin in candy:GetChildren() do
	if BaseService.baseAt(coin.Position) then
		inBase = true
	end
end
check(not inBase, "aucune pièce dans une base")
Fake.moveTo(bob, baseCenter(bob))
Fake.moveTo(alice, baseCenter(alice))
local coin = candy:GetChildren()[1]
local cBefore = cData.Coins
Fake.moveTo(chloe, coin.Position)
coin.Touched:Fire(chloe.Character.HumanoidRootPart)
check(cData.Coins >= cBefore + 25, "Chloé ramasse une pièce")
check(coin.Parent == nil, "la pièce disparaît")
coin.Touched:Fire(chloe.Character.HumanoidRootPart)
check(cData.Coins < cBefore + 25 * 2 + 50, "une pièce ne se ramasse qu'une fois")
Sched.advance(3.5)
check(#candy:GetChildren() == Config.CandyCoinCount, "une nouvelle pièce réapparaît")
-- anti-triche : de loin, rien ; et un maximum par nuit
local far = candy:GetChildren()[1]
Fake.moveTo(chloe, far.Position + Vector3.new(30, 0, 0))
cBefore = cData.Coins
far.Touched:Fire(chloe.Character.HumanoidRootPart)
check(far.Parent ~= nil and cData.Coins < cBefore + 25, "pièce touchée de loin : refusée")
local picked = 1
for _ = 1, Config.CandyMaxPerPlayer + 5 do
	local next = candy:GetChildren()[1]
	if next then
		Fake.moveTo(chloe, next.Position)
		next.Touched:Fire(chloe.Character.HumanoidRootPart)
		if next.Parent == nil then
			picked += 1
		end
		Sched.advance(0.5)
	end
end
check(picked == Config.CandyMaxPerPlayer, "pas plus de " .. Config.CandyMaxPerPlayer .. " pièces par nuit")
Fake.moveTo(chloe, baseCenter(chloe))
check(cData.Missions.List[1].Done == true, "mission 'reste dehors la nuit' réussie par Chloé")
Sched.advance(Config.NightDuration)
check(workspace:FindFirstChild("CandyCoins") == nil, "les pièces disparaissent au matin")

section("Super Nuit")
local wday = os.date("!*t", Fake.os.time()).wday
Config.SuperNight = { WeekDay = wday, StartHour = 0, EndHour = 24 }
Sched.advance(RS:GetAttribute("NextNightAt") - workspace:GetServerTimeNow() + 1)
check(RS:GetAttribute("NightTheme") == "Super", "thème : Super Nuit")
local superAnchor = workspace:FindFirstChild("GloutrouilleAnchor")
check(superAnchor and superAnchor:GetAttribute("Scale") == Config.SuperMonsterScale, "Gloutrouille géant")
local mythicOnPath = false
for _, h in RS.PathGhosts:GetChildren() do
	local g = GhostData.get(h:GetAttribute("GhostId"))
	if g and g.Rarity == "Mythic" then
		mythicOnPath = true
	end
end
check(mythicOnPath, "un Mythique garanti sur le chemin")
check(GhostService.mutationBoost == Config.SuperMutationBoost, "variantes 3 fois plus fréquentes")
Sched.advance(Config.NightDuration)
check(GhostService.mutationBoost == 1, "chances normales après la Super Nuit")
Config.SuperNight = { WeekDay = 7, StartHour = 17, EndHour = 18 }
Config.NightThemes = savedThemes

section("Hiver Hanté")
Config.ForceWinter = true
Sched.advance(31)
check(RS:GetAttribute("EventWinter") == true, "l'hiver est annoncé aux joueurs")
local nextWinterNight = RS:GetAttribute("NextNightAt")
m = mark()
Sched.advance(nextWinterNight - workspace:GetServerTimeNow() + 1)
check(workspace:FindFirstChild("BonhommeGrelotAnchor") ~= nil and workspace:FindFirstChild("GloutrouilleAnchor") == nil, "la nuit d'hiver, c'est le Bonhomme Grelot qui sort")
check(announced("AnnFrostSpawn", m), "un fantôme Givré garanti au début de la nuit")
Sched.advance(Config.NightDuration + 1)
check(workspace:FindFirstChild("BonhommeGrelotAnchor") == nil, "il repart au matin")
Config.ForceWinter = false
Sched.advance(31)
check(RS:GetAttribute("EventWinter") == false, "fin de l'hiver")

section("Rebirth")
m = mark()
aData.Coins = 10
Fake.fire(alice, "Rebirth")
check(notified(alice, "RebirthNotEnough", m) and aData.Rebirths == 0, "rebirth refusé sans argent")
Sched.advance(3)
aData.Coins = 12_000_000
Fake.fire(alice, "Rebirth")
check(aData.Rebirths == 1, "rebirth fait")
check(aData.Coins == Config.StartCoins, "pièces remises à zéro")
local count = 0
for _ in aData.Slots do
	count += 1
end
check(count == 1 and aData.Slots["1"] == Config.StarterGhost, "il ne reste que le fantôme de départ")
check(BaseService.getBase(alice).Pedestals[10]:GetAttribute("Unlocked") == true, "les 10 socles du rez-de-chaussée restent ouverts")
check(next(aData.Stored) == nil, "les pièces en attente repartent à zéro")
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
Sched.advance(13)
check(alice:GetAttribute("DoubleCoins") == nil, "Game Pass pas vraiment acheté : rien")
Fake.ownedPasses = Fake.ownedPasses or {}
Fake.ownedPasses[alice.UserId .. ":555"] = true
Fake.ownedPasses[chloe.UserId .. ":556"] = true
MarketplaceService.PromptGamePassPurchaseFinished:Fire(alice, 555, true)
check(alice:GetAttribute("DoubleCoins") == true and alice:GetAttribute("Multiplier") == mult * 2, "Game Pass x2 actif")
MarketplaceService.PromptGamePassPurchaseFinished:Fire(chloe, 556, true)
Sched.advance(0.1)
check(chloe:GetAttribute("Weapon_BalaiSorciere") == true and hasTool(chloe, "BalaiSorciere"), "Game Pass d'arme : le balai arrive dans le sac")

section("Roue de la Fortune")
local Wheel = Fake.require("ReplicatedStorage.Shared.Wheel")
local MonetizationService = Fake.require("ServerScriptService.Services.MonetizationService")
local Granted = roblox.Enum.ProductPurchaseDecision.PurchaseGranted
local wheelAnchor = workspace.Map:FindFirstChild("FortuneWheelAnchor", true)
check(wheelAnchor ~= nil, "la roue est au milieu de la map")
check(alice:GetAttribute("Spins") == 0, "aucun tour au départ")
check(alice:GetAttribute("RandomItemsRestricted") == false, "règles du pays vérifiées (autorisé)")
Sched.advance(1)
m = mark()
Fake.fire(alice, "SpinWheel")
check(notified(alice, "WheelNoSpins", m), "pas de tour sans achat")
local spinReceipt = { PlayerId = alice.UserId, PurchaseId = "spin-1", ProductId = 1001 }
check(MarketplaceService.ProcessReceipt(spinReceipt) == Granted, "tour de roue acheté")
check(aData.Spins == 1 and alice:GetAttribute("Spins") == 1, "1 tour crédité")
MarketplaceService.ProcessReceipt(spinReceipt)
check(aData.Spins == 1, "le même achat n'est pas crédité deux fois")
local spinId = wheelAnchor:GetAttribute("SpinId")
Sched.advance(1)
m = mark()
Fake.fire(alice, "SpinWheel")
check(aData.Spins == 0, "le tour est utilisé")
check(wheelAnchor:GetAttribute("SpinId") == spinId + 1, "la roue tourne pour tout le monde")
local segIndex = wheelAnchor:GetAttribute("SpinSegment")
check(type(segIndex) == "number" and Wheel.Segments[segIndex] ~= nil, "case tirée par le serveur")
check(wheelAnchor:GetAttribute("SpinnerId") == alice.UserId, "on sait qui joue")
bData.Spins = 1
Sched.advance(0.6)
local mb = mark()
Fake.fire(bob, "SpinWheel")
check(notified(bob, "WheelBusy", mb) and bData.Spins == 1, "un seul joueur à la fois")
local function wonSomething(player, since: number): boolean
	for _, key in { "WheelWinCoins", "WheelWinBoost", "WheelWinGhost", "WheelBaseFull" } do
		if notified(player, key, since) then
			return true
		end
	end
	return false
end
check(not wonSomething(alice, m), "le gain n'arrive pas avant l'arrêt de la roue")
Sched.advance(Wheel.SpinDuration)
check(wonSomething(alice, m), "gain donné quand la roue s'arrête")
aData.Spins = 12
local wins = 0
for _ = 1, 12 do
	Sched.advance(0.6)
	local mi = mark()
	Fake.fire(alice, "SpinWheel")
	Sched.advance(Wheel.SpinDuration + 0.1)
	if wonSomething(alice, mi) then
		wins += 1
	end
end
check(wins == 12, "chaque tour fait gagner quelque chose (" .. wins .. "/12)")
-- case "revenus x2"
aData.BoostUntil = 0 -- la roue a peut-être déjà donné un boost
local multNoBoost = EconomyService.multiplier(alice)
aData.BoostUntil = math.floor(workspace:GetServerTimeNow()) + 60
check(math.abs(EconomyService.multiplier(alice) - multNoBoost * Config.WheelBoostMult) < 0.001, "le boost de la roue double les revenus")
aData.BoostUntil = 0
-- pays où les objets aléatoires payants sont interdits
Fake.restrictedRandomItems[bob.UserId] = true
MonetizationService.setup(bob)
check(bob:GetAttribute("RandomItemsRestricted") == true, "règles du pays : interdit pour Bob")
MonetizationService.studioMode = true
Sched.advance(0.6)
m = mark()
local bobSpins = bData.Spins
Fake.fire(bob, "ShopBuy", "Spin5")
check(bData.Spins == bobSpins and notified(bob, "ShopRestricted", m), "pas de tours de roue pour Bob")
-- mode test de Studio : article sans ID donné gratuitement
Sched.advance(0.6)
m = mark()
Fake.fire(alice, "ShopBuy", "Spin5")
check(aData.Spins == 5 and notified(alice, "ShopStudioFree", m), "Studio : 5 tours donnés pour tester")
MonetizationService.studioMode = false
Sched.advance(0.6)
m = mark()
Fake.fire(alice, "ShopBuy", "Spin5")
check(aData.Spins == 5 and notified(alice, "ShopSoon", m), "vrai jeu sans ID : \"Bientôt\"")
Sched.advance(0.6)
m = mark()
Fake.fire(alice, "ShopBuy", "DoubleCoins")
check(notified(alice, "ShopOwned", m), "Game Pass déjà possédé")
Fake.fire(alice, "ShopBuy", "n'importe quoi")
aData.Spins = 0

section("Monstres achetés avec des Robux")
local Monsters = Fake.require("ReplicatedStorage.Shared.Monsters")
-- on évite la Nuit Hantée pendant ce test
local untilNight = RS:GetAttribute("NextNightAt") - workspace:GetServerTimeNow()
if RS:GetAttribute("NightActive") or untilNight < 150 then
	Sched.advance(math.max(untilNight, 0) + Config.NightDuration + 2)
end
MonetizationService.studioMode = true
park(alice, 140, 8)
park(chloe, 60, -8)
Fake.moveTo(bob, baseCenter(bob))
Sched.advance(0.6)
m = mark()
Fake.fire(alice, "ShopBuy", "MonsterBat")
local batAnchor = workspace:FindFirstChild("ChauveSourisTurboAnchor")
check(batAnchor ~= nil, "la Chauve-Souris Turbo est lâchée")
check(announced("AnnMonsterSummon", m), "annonce pour tout le serveur")
check(batAnchor and batAnchor:GetAttribute("SummonerId") == alice.UserId, "on sait qui l'a lâchée")
Sched.advance(0.6)
m = mark()
Fake.fire(bob, "ShopBuy", "MonsterSpider")
check(notified(bob, "MonsterQueued", m) and workspace:FindFirstChild("MamieToileAnchor") == nil, "le 2e monstre attend son tour")
local targetedAlice, targetedChloe = false, false
for _ = 1, 20 do
	Sched.advance(0.2)
	local target = batAnchor:GetAttribute("TargetUserId")
	targetedAlice = targetedAlice or target == alice.UserId
	targetedChloe = targetedChloe or target == chloe.UserId
end
check(targetedChloe and not targetedAlice, "elle poursuit Chloé, jamais celle qui l'a lâchée")
local chloeCoins = cData.Coins
m = mark()
Fake.moveTo(chloe, batAnchor.Position + Vector3.new(1, -4, 0))
Sched.advance(0.3)
check(notified(chloe, "MonsterCaughtYouFree", m), "Chloé est attrapée")
check(cData.Coins >= chloeCoins, "aucune pièce perdue avec un monstre acheté")
check(inOwnBase(chloe), "retour à la base")
Sched.advance(Monsters.ById.ChauveSourisTurbo.Duration)
check(workspace:FindFirstChild("ChauveSourisTurboAnchor") == nil, "elle repart à la fin")
local spider = workspace:FindFirstChild("MamieToileAnchor")
check(spider ~= nil and spider:GetAttribute("SummonerId") == bob.UserId, "Mamie Toile arrive ensuite")
Sched.advance(Monsters.ById.MamieToile.Duration + 1)
check(workspace:FindFirstChild("MamieToileAnchor") == nil, "plus de monstre")
MonetizationService.studioMode = false

section("Fantômédex")
local IndexService = Fake.require("ServerScriptService.Services.IndexService")
local Rarities = Fake.require("ReplicatedStorage.Shared.Rarities")
check(aData.Discovered[Config.StarterGhost] == true, "le fantôme de départ est dans la collection")
check(aData.Discovered["Caquetome"] == true, "un fantôme reçu entre dans la collection")
local sentIndex = false
for _, entry in Fake.sentToClients do
	if entry.remote == "IndexInfo" and entry.to == alice then
		sentIndex = true
	end
end
check(sentIndex, "la collection est envoyée au joueur")
m = mark()
local c0 = aData.Coins
for _, ghost in GhostData.ByRarity.Common do
	IndexService.discover(alice, ghost.Id)
end
check(aData.IndexRewards.Common == true, "série Commun complète")
check(notified(alice, "IndexRarityDone", m) and aData.Coins >= c0 + Config.IndexRewards.Common, "récompense de la série Commun")
check(not aData.IndexComplete, "pas encore complet")
local multBefore = alice:GetAttribute("Multiplier")
m = mark()
for _, rarity in Rarities.Order do
	if not Rarities.Info[rarity].EventOnly then
		for _, ghost in GhostData.ByRarity[rarity] do
			IndexService.discover(alice, ghost.Id)
		end
	end
end
check(aData.IndexComplete == true, "Fantômédex complet (hors Halloween)")
check(announced("AnnIndexComplete", m), "annonce du Fantômédex complet")
check(math.abs(alice:GetAttribute("Multiplier") - multBefore * (1 + Config.IndexCompleteBonus)) < 0.02, "+10 % de revenus")
local rewardsBefore = aData.Coins
IndexService.discover(alice, GhostData.ByRarity.Common[1].Id)
check(aData.Coins - rewardsBefore < Config.IndexRewards.Common, "une série n'est récompensée qu'une fois")

section("Rareté Secrète et badges")
local function badgeCount(player, badgeId: number): number
	local n = 0
	for _, award in Fake.awardedBadges do
		if award.UserId == player.UserId and award.BadgeId == badgeId then
			n += 1
		end
	end
	return n
end
check(badgeCount(alice, 9000) == 1 and badgeCount(bob, 9000) == 1, "badge de bienvenue pour chaque joueur")
check(badgeCount(bob, 9001) == 1, "badge du premier vol pour Bob, une seule fois")
check(bData.Badges.FirstSteal == true, "badge noté dans la sauvegarde")
m = mark()
GhostService.spawn("Glitchou")
check(announced("AnnSecretSpawn", m), "un fantôme Secret est annoncé à tout le serveur")
local secretHolder
for _, h in RS.PathGhosts:GetChildren() do
	if h:GetAttribute("GhostId") == "Glitchou" then
		secretHolder = h
	end
end
check(secretHolder ~= nil, "le Secret marche sur le chemin")
check(badgeCount(chloe, 9002) == 0, "pas de badge Mythique sans Mythique")
GhostService.giveGhost(chloe, "MegaBouhCosmique")
GhostService.giveGhost(chloe, "Cristalou")
Sched.advance(0.1)
check(badgeCount(chloe, 9002) == 1 and badgeCount(chloe, 9003) == 1, "badges du premier Mythique et du premier Secret")
check(cData.Discovered.Cristalou == true, "le Secret entre dans le Fantômédex")

section("Codes promo")
Sched.advance(1.1)
c0 = aData.Coins
m = mark()
Fake.fire(alice, "RedeemCode", "  bouh 2026 ")
check(notified(alice, "CodeOk", m) and aData.Coins >= c0 + 5000, "code BOUH2026 accepté (minuscules et espaces tolérés)")
Sched.advance(1.1)
m = mark()
Fake.fire(alice, "RedeemCode", "BOUH2026")
check(notified(alice, "CodeUsed", m), "un code ne marche qu'une fois")
Sched.advance(1.1)
m = mark()
Fake.fire(alice, "RedeemCode", "NIMPORTEQUOI")
check(notified(alice, "CodeInvalid", m), "code invalide refusé")
Sched.advance(1.1)
Config.Codes.VIEUXCODE = { Coins = 10, Expires = 1 }
m = mark()
Fake.fire(alice, "RedeemCode", "VIEUXCODE")
check(notified(alice, "CodeExpired", m), "code expiré refusé")
Sched.advance(1.1)
m = mark()
Fake.fire(alice, "RedeemCode", 123)
Fake.fire(alice, "RedeemCode", string.rep("A", 200))
check(not notified(alice, "CodeOk", m), "codes mal formés ignorés")
-- Bob tente de deviner des codes : bloqué après 20 essais
for _ = 1, 20 do
	Sched.advance(1.1)
	Fake.fire(bob, "RedeemCode", "DEVINE")
end
Sched.advance(1.1)
m = mark()
Fake.fire(bob, "RedeemCode", "GLOUTROUILLE")
check(notified(bob, "CodeInvalid", m) and not bData.RedeemedCodes.GLOUTROUILLE, "trop d'essais ratés : codes bloqués")

section("Missions du jour")
for _, p in { alice, bob, chloe } do
	local data = DataService.get(p)
	check(type(data.Missions.List) == "table" and #data.Missions.List >= 1, p.Name .. " a des missions")
end
local sentMissions = false
for _, entry in Fake.sentToClients do
	if entry.remote == "MissionsInfo" and entry.to == alice then
		sentMissions = true
	end
end
check(sentMissions, "les missions sont envoyées au joueur")
-- Alice : gagner des pièces, acheter un Rare, vendre
aData.Missions.List = {
	{ Id = "Earn", Tier = "easy", Target = 5, Progress = 0, Done = false },
	{ Id = "Sell", Tier = "medium", Target = 1, Progress = 0, Done = false },
	{ Id = "BuyRare", Tier = "hard", Target = 1, Progress = 0, Done = false },
}
aData.Missions.BonusDone = false
m = mark()
Sched.advance(6)
check(aData.Missions.List[1].Done, "mission 'Gagne 10 pièces' réussie grâce aux revenus")
check(notified(alice, "MissionDone", m), "message 'Mission réussie'")
GhostService.spawn("Caquetome")
local rareHolder
for _, h in RS.PathGhosts:GetChildren() do
	if h:GetAttribute("GhostId") == "Caquetome" then
		rareHolder = h
	end
end
aData.Coins += 10000
Sched.advance(0.3)
place(alice, pathPosition(rareHolder))
Fake.fire(alice, "BuyGhost", rareHolder.Name)
check(aData.Missions.List[3].Done, "mission 'Achète un Rare ou mieux' réussie")
local rareSlot
for key, id in aData.Slots do
	if id == "Caquetome" then
		rareSlot = tonumber(key)
	end
end
Sched.advance(0.4)
m = mark()
local coinsBeforeBonus = aData.Coins
Fake.moveTo(alice, pedestalPos(alice, rareSlot))
Fake.fire(alice, "SellGhost", rareSlot)
check(aData.Missions.List[2].Done, "mission 'Vends' réussie")
check(aData.Missions.BonusDone and notified(alice, "MissionsAllDone", m), "bonus des 3 missions")
check(aData.Coins > coinsBeforeBonus + 2000, "le bonus est versé")
-- Bob : voler ; Chloé : Marteau Pouet
bData.Missions.List = { { Id = "Steal", Tier = "hard", Target = 1, Progress = 0, Done = false } }
cData.Missions.List = { { Id = "Bonk", Tier = "hard", Target = 1, Progress = 0, Done = false } }
park(alice, 160, 75)
park(chloe, -160, -75)
Sched.advance(1)
steal(bob, alice, 1)
check(bob:GetAttribute("CarryGhost") ~= nil, "vol pour la mission")
Fake.walk(bob, baseCenter(bob), Config.CarrierWalkSpeed * 0.95)
Sched.advance(0.3)
check(bData.Missions.List[1].Done, "mission 'Vole un fantôme' réussie par Bob")
GhostService.giveGhost(alice, "DrapMou")
Sched.advance(1)
local aliceSlot
for key in aData.Slots do
	aliceSlot = tonumber(key)
end
steal(bob, alice, aliceSlot)
place(bob, Vector3.new(0, 3, 12))
Fake.moveTo(chloe, Vector3.new(3, 3, 12))
Sched.advance(3.5)
Fake.fire(chloe, "Bonk")
Sched.advance(0.1)
check(cData.Missions.List[1].Done, "mission 'Marteau Pouet' réussie par Chloé")
-- changement de jour
local oldDay = aData.Missions.Day
aData.Missions.Day = oldDay - 1
check(MissionService.ensure(alice) == true and aData.Missions.Day == oldDay and #aData.Missions.List == 3 and not aData.Missions.BonusDone, "nouvelles missions le lendemain")
check(MissionService.ensure(alice) == false, "pas de nouveau tirage le même jour")

section("Défis de la semaine")
for _, p in { alice, bob, chloe } do
	local data = DataService.get(p)
	check(type(data.Weekly) == "table" and #data.Weekly.List == 3, p.Name .. " a 3 défis de la semaine")
end
bData.Weekly.List = {
	{ Id = "Sell", Tier = "weekly", Target = 1, Progress = 0, Done = false },
	{ Id = "Buy", Tier = "weekly", Target = 2, Progress = 0, Done = false },
	{ Id = "BuyEpic", Tier = "weekly", Target = 1, Progress = 0, Done = false },
}
bData.Weekly.BonusDone = false
m = mark()
local bobCoins = bData.Coins
MissionService.progress(bob, "Sell", 1, 1)
check(bData.Weekly.List[1].Done and notified(bob, "WeeklyDone", m), "défi 'Vends' réussi")
check(bData.Coins >= bobCoins + 5000, "récompense du défi en pièces")
MissionService.progress(bob, "Buy", 1, "DrapMou")
check(bData.Weekly.List[2].Progress == 1 and not bData.Weekly.List[3].Done, "un Commun ne compte pas pour 'Épique ou mieux'")
local ghostsBefore = 0
for _ in bData.Slots do
	ghostsBefore += 1
end
m = mark()
MissionService.progress(bob, "Buy", 1, "CrepeFrisson")
check(bData.Weekly.List[2].Done and bData.Weekly.List[3].Done, "un Épique compte pour les deux défis d'achat")
check(bData.Weekly.BonusDone and (notified(bob, "WeeklyAllDone", m) or notified(bob, "WeeklyAllDoneCoins", m)), "bonus des 3 défis")
check(announced("AnnWeekly", m), "annonce pour tout le serveur")
local goldEpic = false
for _, id in bData.Slots do
	if string.find(id, "#Gold", 1, true) and GhostData.get(id).Rarity == "Epic" then
		goldEpic = true
	end
end
check(goldEpic or notified(bob, "WeeklyAllDoneCoins", m), "Bob reçoit un fantôme Épique Doré")
local oldWeek = bData.Weekly.Week
bData.Weekly.Week = oldWeek - 1
check(MissionService.ensureWeekly(bob) and bData.Weekly.Week == oldWeek and not bData.Weekly.BonusDone, "nouveaux défis la semaine suivante")

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
local chloeSaved = serde.decode("json", raw)
local stillOnPedestal = false
for _, id in chloeSaved.Slots do
	if id == "WifiFantome" then
		stillOnPedestal = true
	end
end
check(not stillOnPedestal, "la sauvegarde de Chloé ne l'a plus sur ses socles")
check(chloeSaved.Discovered.WifiFantome == true, "mais il reste dans sa collection")
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
local savedAlice = store["Player_101"]
check(savedAlice ~= nil and string.find(savedAlice, '"IndexComplete":true') ~= nil and string.find(savedAlice, "BOUH2026") ~= nil, "Fantômédex et codes sauvegardés")

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
