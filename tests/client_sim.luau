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
check(floorTag and findText(floorTag, "Étage 2 : 🪙 50K") ~= nil, "prix de l'étage affiché sur l'ascenseur")
local floorPrompt = find(upPad, function(d)
	return d.ClassName == "ProximityPrompt"
end)
check(floorPrompt and floorPrompt.Enabled and string.find(floorPrompt.ActionText, "étage", 1, true) ~= nil, "bouton 'Acheter l'étage 2'")
aData.Coins = Config.FloorPrice + 1000
floorPrompt.Triggered:Fire()
Sched.advance(0.3)
check(aData.Floors == 2, "étage acheté depuis le bouton")
check(findText(floorTag, "⬆️") ~= nil and not floorPrompt.Enabled, "l'ascenseur affiche 'Étage 2'")
local lockTag = find(aliceBase.Model.LockButton, function(d)
	return d.ClassName == "BillboardGui"
end)
check(lockTag and findText(lockTag, "VERROU") ~= nil, "panneau 'VERROU' au fond de la base")
check(lockTag and lockTag.Adornee and lockTag.Adornee.ClassName == "Attachment" and lockTag.Adornee.WorldPosition.Y > aliceBase.Model.LockButton.Position.Y + 4, "le panneau est bien au-dessus du bouton")
-- pièges : prix et bouton d'achat sur chaque emplacement
local bananaTrap = aliceBase.Model.Traps:FindFirstChild("Trap_Banana")
local bananaPrompt = find(bananaTrap, function(d)
	return d.ClassName == "ProximityPrompt"
end)
check(bananaPrompt and bananaPrompt.Enabled, "bouton pour poser la peau de banane")
check(findText(bananaTrap, "Peau de banane : 🪙 2.5K") ~= nil, "prix du piège affiché")
aData.Coins = 100000
Fake.moveTo(alice, bananaTrap.Spot.Position + Vector3.new(0, 3, 2))
bananaPrompt.Triggered:Fire(alice)
Sched.advance(0.5)
check(aData.Traps and aData.Traps.Banana, "peau de banane achetée depuis le bouton")
check(not bananaPrompt.Enabled, "plus de bouton une fois posé")

section("Écran du classement")
local LeaderboardServiceSim = Fake.require("ServerScriptService.Services.LeaderboardService")
LeaderboardServiceSim.refresh()
Sched.advance(0.2)
local boardPart = workspace.Map:FindFirstChild("Leaderboard")
check(boardPart and #boardPart:GetChildren() == 2, "écran double face au-dessus du chemin")
check(boardPart and findText(boardPart, "PLUS GRANDS VOLEURS") ~= nil, "titre du classement")
check(boardPart and findText(boardPart, "Bob  :  🦹 1") ~= nil, "Bob apparaît avec son vol")
check(boardPart and findText(boardPart, "Remise à zéro dans") ~= nil, "compte à rebours de la semaine")

section("Verrou par le bouton au fond de la base")
Sched.advance(5)
check(find(gui.SAG_HUD, function(d)
	return d.Name == "Lock"
end) == nil, "plus de bouton de verrou sur l'écran")
local lockPill = find(gui.SAG_HUD, function(d)
	return d.Name == "LockPill"
end)
check(lockPill and lockPill.Visible and findText(lockPill, "Verrou prêt") ~= nil, "pastille 'Verrou prêt'")
local lockPart = BaseService.getBase(alice).Model:FindFirstChild("LockButton")
local lockPrompt = find(lockPart, function(d)
	return d.ClassName == "ProximityPrompt"
end)
check(lockPrompt ~= nil and lockPrompt.Enabled, "bouton du verrou au fond de la base")
Fake.moveTo(alice, Vector3.new(150, 3, 70))
lockPrompt.Triggered:Fire(alice)
Sched.advance(0.6)
check(not BaseService.isLocked(BaseService.getBase(alice)), "pas de verrou à distance")
Fake.moveTo(alice, lockPart.Position + Vector3.new(0, 3, -2))
lockPrompt.Triggered:Fire(alice)
Sched.advance(0.3)
check(BaseService.isLocked(BaseService.getBase(alice)), "base verrouillée avec le bouton")
local gate = BaseService.getBase(alice).Model:FindFirstChild("Barrier")
check(gate and gate.Collider.CanCollide == false, "Alice peut traverser sa propre barrière")
check(findText(lockPill, "Verrouillée : 4") ~= nil, "la pastille affiche le compte à rebours (" .. tostring(lockPill:FindFirstChild("Text").Text) .. ")")
local visibleBars = 0
for _, d in gate:GetDescendants() do
	if d.Name == "Bar" and d.Transparency >= 0.8 then
		visibleBars += 1
	end
end
check(visibleBars >= 5, "chez soi, la barrière est presque invisible")
check(findText(gui.SAG_HUD, "Base verrouillée") ~= nil, "message 'Base verrouillée !'")

section("Rebirth par le panneau")
aData.Coins = 12_000_000
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
local function tab(id: string)
	local button = find(shop, function(d)
		return d.Name == "Tab_" .. id
	end)
	button.Activated:Fire()
	Sched.advance(0.6)
	return find(shop, function(d)
		return d.Name == "Page_" .. id
	end)
end
check(find(shop, function(d)
	return d.Name == "Tab_Weapons"
end) ~= nil, "onglets de la boutique")
local weaponsPage = tab("Weapons")
check(weaponsPage.Visible and findText(weaponsPage, "Offerte") ~= nil, "onglet Armes : la batte est offerte")
check(findText(weaponsPage, "Marteau Pouet Géant") ~= nil and findText(weaponsPage, "Portée") ~= nil, "armes payantes avec leur portée")
local monstersPage = tab("Monsters")
check(monstersPage.Visible and findText(monstersPage, "Mamie Toile") ~= nil, "onglet Monstres")
local wheelPage = tab("Wheel")
check(wheelPage.Visible and not weaponsPage.Visible, "un seul onglet affiché à la fois")
local odds = 0
for _, d in wheelPage:GetDescendants() do
	if string.sub(d.Name, 1, 5) == "Odds_" and string.find(d.Text, "%", 1, true) then
		odds += 1
	end
end
check(odds == 8, "les chances de chaque case sont affichées avant l'achat (" .. odds .. ")")
check(findText(wheelPage, "Un fantôme Mythique  :  2 %") ~= nil, "exemple : Mythique 2 %")
shop.Close.Activated:Fire()

section("Roue de la Fortune côté joueur")
local wheelModel = workspace:FindFirstChild("FortuneWheel")
check(wheelModel ~= nil, "la roue est dessinée au milieu de la map")
local holders = {}
for _, d in wheelModel:GetDescendants() do
	if d:GetAttribute("Segment") then
		holders[d:GetAttribute("Segment")] = d
	end
end
check(#holders == 8 and holders[1]:FindFirstChild("SegmentLabel") ~= nil, "8 cases avec leur texte")
aData.Spins = 1
alice:SetAttribute("Spins", 1)
shopButton.Activated:Fire()
Sched.advance(0.3)
wheelPage = tab("Wheel")
local spinButton = find(wheelPage, function(d)
	return d.Name == "SpinButton"
end)
Fake.moveTo(alice, Vector3.new(150, 3, 70))
spinButton.Activated:Fire()
Sched.advance(0.3)
check(aData.Spins == 1 and findText(gui.SAG_HUD, "Va devant la roue") ~= nil, "il faut être devant la roue pour tourner")
local wheelAnchor = workspace.Map:FindFirstChild("FortuneWheelAnchor", true)
Fake.moveTo(alice, wheelAnchor.Position + Vector3.new(0, -8, -8))
spinButton.Activated:Fire()
Sched.advance(0.5)
check(aData.Spins == 0, "Alice tourne la roue")
check(shop.Visible == false, "la boutique se ferme pour regarder la roue")
local winning = wheelAnchor:GetAttribute("SpinSegment")
local startAngle = holders[1].CFrame
Sched.advance(2)
check(holders[1].CFrame ~= startAngle, "la roue tourne")
Sched.advance(5)
local highest, highestY = nil, -math.huge
for index, holder in holders do
	if holder.Position.Y > highestY then
		highest, highestY = index, holder.Position.Y
	end
end
check(highest == winning, "la roue s'arrête sur la case tirée par le serveur (" .. tostring(highest) .. " / " .. tostring(winning) .. ")")
check(findText(gui.SAG_HUD, "Roue de la Fortune") ~= nil or findText(gui.SAG_HUD, "Base pleine") ~= nil, "message du gain")

section("Batte côté joueur")
local bat = alice.Backpack:FindFirstChild("Batte") or alice.Character:FindFirstChild("Batte")
check(bat ~= nil and bat:GetAttribute("WeaponId") == "Batte", "Alice a sa batte dans son sac")
check(bat and bat:FindFirstChild("Handle") ~= nil, "la batte a une poignée")

section("Animations avec les objets")
local function shoulder(p)
	return p.Character.RightUpperArm.RightShoulder
end
local function sameCf(a, b): boolean
	return (a.Position - b.Position).Magnitude < 1e-3 and a.LookVector:Dot(b.LookVector) > 0.9999 and a.UpVector:Dot(b.UpVector) > 0.9999
end
local restRight = roblox.CFrame.new(1, 0.56, 0)
check(sameCf(shoulder(alice).C0, restRight) and sameCf(shoulder(bob).C0, restRight), "bras au repos")
Sched.advance(2)
local batTool = alice.Backpack:FindFirstChild("Batte") or alice.Character:FindFirstChild("Batte")
batTool.Activated:Fire()
Sched.advance(0.1)
check(batTool.Parent == alice.Character, "Alice prend la batte en main")
local toolAnim = batTool:FindFirstChild("toolanim")
check(toolAnim and toolAnim.ClassName == "StringValue" and toolAnim.Value == "Slash", "animation officielle de Roblox demandée (\"Slash\")")
check(sameCf(shoulder(alice).C0, restRight), "on ne tord plus les articulations à la main")
check(batTool.Handle.SwingTrail.Enabled, "traînée colorée pendant le coup")
Sched.advance(1)
check(not batTool.Handle.SwingTrail.Enabled, "la traînée s'éteint")
-- Aspira-Fantôme de Bob : Alice voit le rayon vert
bob:SetAttribute("Weapon_AspiraFantome", true)
Sched.advance(2)
Fake.fire(bob, "Bonk", "AspiraFantome")
Sched.advance(0.05)
check(workspace:FindFirstChild("VacuumBeam") ~= nil, "Alice voit le rayon de l'aspirateur de Bob")
Sched.advance(1)
check(workspace:FindFirstChild("VacuumBeam") == nil, "le rayon disparaît")
-- porter un fantôme : bras levés, puis retour exact au repos
bob:SetAttribute("CarryGhost", "DrapMou")
Sched.advance(0.2)
check(shoulder(bob).C0.UpVector.Y < 0, "Bob porte le fantôme bras levés")
Sched.advance(1)
check(shoulder(bob).C0.UpVector.Y < 0, "et les garde levés")
bob:SetAttribute("CarryGhost", nil)
Sched.advance(0.2)
check(sameCf(shoulder(bob).C0, restRight), "bras exactement au repos quand il ne porte plus rien")
check(shoulder(bob):GetAttribute("RestC0") == nil, "plus rien en mémoire")
for _ = 1, 3 do
	bob:SetAttribute("CarryGhost", "DrapMou")
	Sched.advance(0.3)
	bob:SetAttribute("CarryGhost", nil)
	Sched.advance(0.3)
end
check(sameCf(shoulder(bob).C0, restRight), "pas de décalage qui s'accumule après plusieurs vols")

section("Monstre lâché par un joueur")
local MonsterService = Fake.require("ServerScriptService.Services.MonsterService")
MonsterService.summon(bob, "MamieToile")
Sched.advance(0.5)
local spiderModel = workspace:FindFirstChild("MamieToile")
check(spiderModel ~= nil, "Mamie Toile est dessinée")
check(spiderModel and findText(spiderModel, "lâché par Bob") ~= nil, "on voit qui l'a lâchée")
check(findText(gui.SAG_Announce, "Bob a lâché Mamie Toile") ~= nil, "annonce pour tout le serveur")
Sched.advance(50)
check(workspace:FindFirstChild("MamieToile") == nil, "elle disparaît à la fin")

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

section("Fantôme dessiné à la main dans Studio")
local GhostFactory = Fake.require("ReplicatedStorage.Shared.GhostFactory")
local folder = Fake.Instance.new("Folder")
folder.Name = "GhostModels"
local custom = Fake.Instance.new("Model")
custom.Name = "DrapMou"
local body = Fake.Instance.new("Part")
body.Name = "MonCorps"
body.Size = Vector3.new(4, 6, 3)
body.CFrame = roblox.CFrame.new(50, 20, 10)
body.Anchored = false
body.CanCollide = true
body.Parent = custom
custom.Parent = folder
folder.Parent = RS
local built = GhostFactory.build("DrapMou#Gold")
local copy = built:FindFirstChild("MonCorps")
check(copy ~= nil, "le modèle de Studio remplace le fantôme fabriqué")
check(copy and copy.Anchored and not copy.CanCollide, "ses pièces sont ancrées et sans collision")
check(built.PrimaryPart and built.PrimaryPart.Name == "Root", "il a une racine pour être déplacé")
check((built:GetAttribute("Top") or 0) > 0 and (built:GetAttribute("Bottom") or 0) > 0, "hauteur calculée")
check(copy and (copy.Position - built.PrimaryPart.Position).Magnitude < 0.01, "centré sur sa racine")
check(body.Parent == custom and body.CanCollide, "le modèle d'origine n'est pas modifié")
folder:Destroy()
check(GhostFactory.build("DrapMou"):FindFirstChild("MonCorps") == nil, "sans le dossier, retour au modèle fabriqué")

section("Bilan")
for _, w in Fake.warnings do
	print("  avertissement : " .. w)
end
check(#Fake.Sched.errors == 0, "aucune erreur Luau (client + serveur) : " .. #Fake.Sched.errors)
print(string.format("\n%d vérifications réussies, %d échouées", passed, failed))
if failed > 0 then
	process.exit(1)
end
