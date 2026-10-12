--[[
	Simulation côté joueur : `lune run tests/client_sim.luau`
	Lance le vrai serveur ET le vrai code client d'Alice, puis joue comme elle :
	tutoriel, achat par le bouton du chemin, HUD, Marteau Pouet, panneaux, nuit...
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

local function find(root, predicate)
	for _, d in root:GetDescendants() do
		if predicate(d) then
			return d
		end
	end
	return nil
end
local function findText(root, pattern: string)
	return find(root, function(d)
		return type(d.Text) == "string" and string.find(d.Text, pattern, 1, true) ~= nil
	end)
end

math.randomseed(11)
Fake.mountProject()
local Config = Fake.require("ReplicatedStorage.Shared.Config")
Config.NewPlayerShield = 5
Config.NightThemes = { Classic = 0, Fog = 0, Candy = 1 } -- on teste la Nuit des Bonbons
Fake.runServer()
Fake.startFramePump(10)
Sched.advance(1)

local DataService = Fake.require("ServerScriptService.Services.DataService")
local BaseService = Fake.require("ServerScriptService.Services.BaseService")
local RS = Fake.service("ReplicatedStorage")
local workspace = Fake.workspace

local alice = Fake.addPlayer("Alice", 201)
Fake.startClient(alice) -- comme dans Roblox : le script client démarre dès l'arrivée
local bob = Fake.addPlayer("Bob", 202)
Sched.advance(2)
local earlyToast = findText(alice.PlayerGui, "Cadeau !") ~= nil
Sched.advance(2)

local gui = alice:FindFirstChild("PlayerGui")
local aData = DataService.get(alice)

section("Démarrage du client")
for _, e in Fake.propertyErrors do
	print("  propriété invalide : " .. e)
end
check(#Fake.propertyErrors == 0, "toutes les propriétés Roblox utilisées existent")
check(#Fake.Sched.errors == 0, "aucune erreur au démarrage")
for _, w in Fake.warnings do
	if string.find(w, "[Client]", 1, true) then
		print("  " .. w)
	end
end
check(gui:FindFirstChild("SAG_HUD") ~= nil, "le HUD existe")
check(gui:FindFirstChild("SAG_Panels") ~= nil, "les panneaux existent")
check(gui:FindFirstChild("SAG_Announce") ~= nil, "les annonces existent")
check(workspace:FindFirstChild("ClientPathGhosts") and #workspace.ClientPathGhosts:GetChildren() >= 5, "les fantômes du chemin sont affichés")
local clientGhosts = workspace:FindFirstChild("ClientBaseGhosts")
check(clientGhosts and #clientGhosts:GetChildren() == 2, "les 2 fantômes de départ sont affichés sur les socles")
check(findText(gui, "TA BASE") == nil, "le panneau de base n'est pas dans l'interface")
check(findText(workspace.Map, "TA BASE") ~= nil, "le panneau 'TA BASE' est sur la base d'Alice")
check(findText(workspace.Map, "Base de Bob") ~= nil, "le panneau 'Base de Bob'")
check(earlyToast, "message du fantôme offert affiché")

section("HUD")
Sched.advance(1)
local coinLabel = find(gui.SAG_HUD, function(d)
	return d.Name == "TextLabel" and d.TextColor3 == roblox.Color3.fromRGB(255, 205, 60) and d.Parent and d.Parent.Name == "Coins"
end)
check(coinLabel ~= nil and coinLabel.Text == tostring(math.floor(aData.Coins)), "le compteur affiche les pièces (" .. tostring(coinLabel and coinLabel.Text) .. ")")
check(findText(gui.SAG_HUD, "+2/s") ~= nil, "revenu affiché +2/s")
check(findText(gui.SAG_HUD, "Nuit dans") ~= nil, "minuteur de nuit affiché")

section("Tutoriel étape 1 : acheter")
local marker = workspace:FindFirstChild("TutorialMarker")
check(marker ~= nil, "la flèche du tutoriel est là")
check(marker and findText(marker, "Achète") ~= nil, "flèche 'Achète !'")
-- Alice va sur le chemin et appuie sur le bouton du fantôme le plus proche
aData.Coins = 5000
local pathModels = workspace.ClientPathGhosts:GetChildren()
local cheapest, cheapestPrompt = nil, nil
for _, model in pathModels do
	local prompt = find(model, function(d)
		return d.ClassName == "ProximityPrompt"
	end)
	local GhostData = Fake.require("ReplicatedStorage.Shared.GhostData")
	local ghost = GhostData.get(model:GetAttribute("GhostId"))
	if prompt and ghost.Price <= 5000 and (not cheapest or model.PrimaryPart.Position.X > cheapest.PrimaryPart.Position.X) then
		cheapest, cheapestPrompt = model, prompt
	end
end
check(cheapestPrompt ~= nil and string.find(cheapestPrompt.ActionText, "Acheter", 1, true) ~= nil, "bouton 'Acheter' en français")
Fake.moveTo(alice, cheapest.PrimaryPart.Position + Vector3.new(0, -1, 3))
cheapestPrompt.Triggered:Fire()
Sched.advance(0.5)
local count = 0
for _ in aData.Slots do
	count += 1
end
check(count == 2, "achat par le bouton du client")
check(#clientGhosts:GetChildren() == 3, "le nouveau fantôme apparaît sur le socle")
check(marker.Parent and findText(marker, "Récupère") ~= nil, "tutoriel étape 2 : 'Récupère !'")

section("Tutoriel étapes 2 et 3, récolte des pièces")
local aliceBase = BaseService.getBase(alice)
local pad = aliceBase.Pedestals[1]:FindFirstChild("CollectPad")
check(findText(gui.SAG_HUD, "à récupérer") ~= nil, "pastille 'à récupérer' dans le HUD")
local padTag = pad:FindFirstChildOfClass("BillboardGui")
check(padTag and padTag.Enabled and findText(padTag, "🪙") ~= nil, "pièces affichées au-dessus de la plaque verte")
check((marker.Position - pad.Position).Magnitude < 8, "la flèche montre la plaque verte")
Fake.moveTo(alice, pad.Position + Vector3.new(0, 3, 0))
local coinsBeforePad = aData.Coins
pad.Touched:Fire(alice.Character.HumanoidRootPart)
Sched.advance(0.5)
check(aData.Coins > coinsBeforePad, "récolte en passant sur la plaque")
check(findText(workspace, "+") ~= nil, "le +X doré s'affiche")
check(marker.Parent and findText(marker, "Vole") ~= nil, "tutoriel étape 3 : 'Vole !'")
Sched.advance(26)
check(workspace:FindFirstChild("TutorialMarker") == nil, "tutoriel terminé")
check(aData.TutorialDone == true, "le serveur a noté la fin du tutoriel")
Sched.advance(3)
local daily = gui.SAG_Panels:FindFirstChild("Daily")
check(daily and daily.Visible == true, "le cadeau du jour s'ouvre tout seul après le tutoriel")

section("Cadeau du jour (panneau)")
local claim = find(daily, function(d)
	return d.ClassName == "TextButton" and findText(d, "Récupérer") ~= nil
end)
check(claim ~= nil, "bouton 'Récupérer'")
local before = aData.Coins
if claim then
	claim.Activated:Fire()
end
Sched.advance(0.6)
check(aData.Coins > before and aData.DailyStreak == 1, "cadeau récupéré par le bouton")
check(findText(daily, "Prochain cadeau") ~= nil, "le bouton affiche le prochain cadeau")
local close = daily:FindFirstChild("Close")
close.Activated:Fire()
check(daily.Visible == false, "fermeture du panneau")

section("Vol vu par Alice + Marteau Pouet")
Sched.advance(5) -- fin du bouclier
local slot = 1
Fake.moveTo(bob, BaseService.pedestalPosition(BaseService.getBase(alice), slot) + Vector3.new(2, 1, 0))
local index = BaseService.getBase(alice).Index
Fake.fire(bob, "StealBegin", index, slot)
Sched.advance(1.6)
Fake.moveTo(alice, Vector3.new(150, 3, 70))
Fake.fire(bob, "Steal", index, slot)
Sched.advance(0.3)
check(bob:GetAttribute("CarryGhost") ~= nil, "Bob vole Alice")
check(workspace:FindFirstChild("ClientCarried") and #workspace.ClientCarried:GetChildren() == 1, "le fantôme volé flotte au-dessus de Bob")
check(bob.Character:FindFirstChildOfClass("Highlight") ~= nil, "Bob est surligné en rouge")
check(findText(gui.SAG_HUD, "vole ton") ~= nil, "Alice est prévenue du vol")
local bonk = find(gui.SAG_HUD, function(d)
	return d.Name == "Bonk"
end)
check(bonk and bonk.Visible == false, "pas de bouton Pouet loin du voleur")
Fake.moveTo(bob, Vector3.new(0, 3, 12))
Fake.moveTo(alice, Vector3.new(7, 3, 12))
Sched.advance(0.3)
check(bonk and bonk.Visible == true, "le bouton Pouet apparaît près du voleur")
bonk.Activated:Fire()
Sched.advance(0.3)
check(bob:GetAttribute("CarryGhost") == nil, "Pouet ! Bob a lâché le fantôme")
check(#workspace.ClientCarried:GetChildren() == 0, "le fantôme ne flotte plus")
check(bob.Character:FindFirstChildOfClass("Highlight") == nil, "plus de surlignage")

section("Annonce d'un vol réussi")
Sched.advance(4)
Fake.moveTo(alice, Vector3.new(150, 3, 70))
Fake.moveTo(bob, BaseService.pedestalPosition(BaseService.getBase(alice), slot) + Vector3.new(2, 1, 0))
Fake.fire(bob, "StealBegin", index, slot)
Sched.advance(1.6)
Fake.fire(bob, "Steal", index, slot)
Fake.walk(bob, BaseService.getBase(bob).Origin.Position + Vector3.new(0, 3, 0), 9)
Sched.advance(0.5)
check(findText(gui.SAG_Announce, "Bob a volé") ~= nil, "bannière 'Bob a volé ... à Alice !'")

section("Étage 2 (ascenseur et achat)")
local upPad = aliceBase.Model:FindFirstChild("UpPad")
local floorTag = upPad:FindFirstChildOfClass("BillboardGui")
check(floorTag and findText(floorTag, "Étage 2 : 🪙 25K") ~= nil, "prix de l'étage affiché sur l'ascenseur")
local floorPrompt = find(upPad, function(d)
	return d.ClassName == "ProximityPrompt"
end)
check(floorPrompt and floorPrompt.Enabled and string.find(floorPrompt.ActionText, "étage", 1, true) ~= nil, "bouton 'Acheter l'étage 2'")
aData.Coins = Config.FloorPrice + 1000
floorPrompt.Triggered:Fire()
Sched.advance(0.3)
check(aData.Floors == 2, "étage acheté depuis le bouton")
check(findText(floorTag, "⬆️") ~= nil and not floorPrompt.Enabled, "l'ascenseur affiche 'Étage 2'")
local lockTag = aliceBase.Model.LockButton:FindFirstChildOfClass("BillboardGui")
check(lockTag and findText(lockTag, "VERROU") ~= nil, "panneau 'VERROU' au fond de la base")

section("Écran du classement")
local LeaderboardServiceSim = Fake.require("ServerScriptService.Services.LeaderboardService")
LeaderboardServiceSim.refresh()
Sched.advance(0.2)
local boardPart = workspace.Map:FindFirstChild("Leaderboard")
check(boardPart and #boardPart:GetChildren() == 2, "écran double face au-dessus du chemin")
check(boardPart and findText(boardPart, "PLUS GRANDS VOLEURS") ~= nil, "titre du classement")
check(boardPart and findText(boardPart, "Bob  :  🦹 1") ~= nil, "Bob apparaît avec son vol")
check(boardPart and findText(boardPart, "Remise à zéro dans") ~= nil, "compte à rebours de la semaine")

section("Verrou par le bouton du HUD")
Sched.advance(5)
local lock = find(gui.SAG_HUD, function(d)
	return d.Name == "Lock"
end)
lock.Activated:Fire()
Sched.advance(0.3)
check(BaseService.isLocked(BaseService.getBase(alice)), "base verrouillée par le bouton")
local gate = BaseService.getBase(alice).Model:FindFirstChild("Barrier")
check(gate and gate.Collider.CanCollide == false, "Alice peut traverser sa propre barrière")
local caption = lock:FindFirstChild("Caption")
check(caption and (caption.Text == "1:00" or string.match(caption.Text, "^%d+s$")), "le bouton affiche le compte à rebours (" .. tostring(caption and caption.Text) .. ")")
check(findText(gui.SAG_HUD, "Base verrouillée") ~= nil, "message 'Base verrouillée !'")

section("Rebirth par le panneau")
aData.Coins = 6_000_000
Sched.advance(1.2)
local rebirthButton = find(gui.SAG_HUD, function(d)
	return d.Name == "Rebirth"
end)
rebirthButton.Activated:Fire()
local rebirthPanel = gui.SAG_Panels:FindFirstChild("Rebirth")
check(rebirthPanel.Visible == true, "panneau rebirth ouvert")
Sched.advance(0.6)
local confirm = find(rebirthPanel, function(d)
	return d.ClassName == "TextButton" and findText(d, "REBIRTH") ~= nil
end)
check(confirm ~= nil, "bouton REBIRTH !")
confirm.Activated:Fire()
check(findText(rebirthPanel, "Sûr ?") ~= nil, "demande de confirmation")
check(aData.Rebirths == 0, "pas de rebirth au premier clic")
confirm.Activated:Fire()
Sched.advance(0.5)
check(aData.Rebirths == 1, "rebirth au deuxième clic")
check(findText(gui.SAG_Announce, "rebirth") ~= nil, "annonce du rebirth")

section("Boutique")
local shopButton = find(gui.SAG_HUD, function(d)
	return d.Name == "Shop"
end)
shopButton.Activated:Fire()
local shop = gui.SAG_Panels:FindFirstChild("Shop")
check(shop.Visible == true, "boutique ouverte")
Sched.advance(0.6)
check(findText(shop, "Bientôt") ~= nil, "articles 'Bientôt' tant que les IDs sont à 0")

section("Fantômédex (panneau)")
local indexButton = find(gui.SAG_HUD, function(d)
	return d.Name == "Index"
end)
check(indexButton ~= nil, "bouton Fantômédex")
indexButton.Activated:Fire()
local indexPanel = gui.SAG_Panels:FindFirstChild("Index")
check(indexPanel and indexPanel.Visible == true, "panneau Fantômédex ouvert")
Sched.advance(0.6)
local grid = find(indexPanel, function(d)
	return d.Name == "Grid"
end)
local tileCount = 0
for _, child in grid:GetChildren() do
	if child.ClassName == "TextButton" then
		tileCount += 1
	end
end
local GhostDataClient = Fake.require("ReplicatedStorage.Shared.GhostData")
check(tileCount == #GhostDataClient.List, "une case par fantôme (" .. tileCount .. ")")
local starterTile = grid:FindFirstChild(Config.StarterGhost)
local starterViewport = starterTile and starterTile:FindFirstChildOfClass("ViewportFrame")
check(starterViewport and starterViewport.ImageColor3 == roblox.Color3.new(1, 1, 1), "le Drap Mou est visible en couleur")
check(starterViewport and starterViewport.CurrentCamera ~= nil and #starterViewport:GetChildren() >= 2, "mini-aperçu 3D du fantôme")
local mythicTile = grid:FindFirstChild("SpectroPizzaSupreme")
check(mythicTile and mythicTile:FindFirstChildOfClass("ViewportFrame").ImageColor3 == roblox.Color3.new(0, 0, 0), "un fantôme pas trouvé est une silhouette noire")
check(mythicTile and findText(mythicTile, "???") ~= nil, "nom caché : ???")
check(findText(indexPanel, "Commun") ~= nil, "progression par rareté")
starterTile.Activated:Fire()
Sched.advance(0.1)
check(findText(indexPanel, "flotter") ~= nil, "toucher une case affiche la blague du fantôme")
indexPanel.Close.Activated:Fire()

section("Missions du jour (panneau)")
local missionsButton = find(gui.SAG_HUD, function(d)
	return d.Name == "MissionsButton"
end)
check(missionsButton ~= nil, "bouton Missions")
missionsButton.Activated:Fire()
local missionsPanel = gui.SAG_Panels:FindFirstChild("Missions")
check(missionsPanel and missionsPanel.Visible == true, "panneau Missions ouvert")
Sched.advance(0.6)
for i = 1, 3 do
	local card = missionsPanel:FindFirstChild("Mission" .. i, true)
	local text = card and card:FindFirstChild("Text")
	check(text and #text.Text > 5 and not string.find(text.Text, "Mission_", 1, true), "mission " .. i .. " affichée (" .. tostring(text and text.Text) .. ")")
	local count = card and card:FindFirstChild("Count")
	check(count and string.find(count.Text, "/", 1, true) ~= nil, "progression de la mission " .. i)
end
check(findText(missionsPanel, "Nouvelles missions dans") ~= nil, "compte à rebours des missions")
check(findText(missionsPanel, "Les 3 missions") ~= nil or findText(missionsPanel, "Bonus du jour") ~= nil, "ligne du bonus")
missionsPanel.Close.Activated:Fire()

section("Codes secrets (boutique)")
shopButton.Activated:Fire()
Sched.advance(0.3)
local codeBox = find(shop, function(d)
	return d.Name == "CodeBox"
end)
local codeButton = find(shop, function(d)
	return d.Name == "CodeButton"
end)
check(codeBox ~= nil and codeButton ~= nil, "case et bouton des codes")
local coinsBeforeCode = aData.Coins
codeBox.Text = "bouh2026"
codeButton.Activated:Fire()
Sched.advance(0.3)
check(aData.Coins >= coinsBeforeCode + 5000, "code tapé dans la boutique : +5000 pièces")
check(codeBox.Text == "", "la case se vide après l'envoi")
check(findText(gui.SAG_HUD, "Code accepté") ~= nil, "message 'Code accepté'")
shop.Close.Activated:Fire()

section("Nuit Hantée côté joueur")
local nextNight = RS:GetAttribute("NextNightAt")
Sched.advance(nextNight - workspace:GetServerTimeNow() + 1)
check(findText(gui.SAG_Announce, "NUIT DES BONBONS") ~= nil, "annonce de la Nuit des Bonbons")
Sched.advance(3)
check(findText(gui.SAG_HUD, "🍬 Nuit :") ~= nil, "minuteur de la Nuit des Bonbons")
check(workspace:FindFirstChild("Gloutrouille") ~= nil, "le monstre est dessiné")
local coinsFolder = workspace:FindFirstChild("CandyCoins")
local firstCoin = coinsFolder and coinsFolder:GetChildren()[1]
check(firstCoin ~= nil, "des pièces sur le chemin")
local coinCf = firstCoin.CFrame
Sched.advance(0.3)
check(firstCoin.CFrame ~= coinCf, "les pièces tournent")
local beforeCoin = aData.Coins
Fake.moveTo(alice, firstCoin.Position)
firstCoin.Touched:Fire(alice.Character.HumanoidRootPart)
check(aData.Coins > beforeCoin, "Alice ramasse une pièce")
local weekendPill = findText(gui.SAG_HUD, "Week-end")
check(weekendPill and weekendPill.Parent.Visible == false, "pas de pastille Week-end x2 en semaine")
local lighting = Fake.service("Lighting")
check(lighting.ClockTime == 22.5, "le ciel passe en mode nuit")
Sched.advance(Config.NightDuration)
check(workspace:FindFirstChild("Gloutrouille") == nil, "le monstre disparaît au matin")
check(math.abs(lighting.ClockTime - 18.3) < 0.01, "le jour revient")

section("Bilan")
for _, w in Fake.warnings do
	print("  avertissement : " .. w)
end
check(#Fake.Sched.errors == 0, "aucune erreur Luau (client + serveur) : " .. #Fake.Sched.errors)
print(string.format("\n%d vérifications réussies, %d échouées", passed, failed))
if failed > 0 then
	process.exit(1)
end
