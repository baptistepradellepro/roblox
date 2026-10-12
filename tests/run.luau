--[[
	Tests automatiques (hors Roblox) avec Lune : `lune run tests/run.luau`
	  - logique pure : formats, raretés, données des fantômes, textes FR/EN
	  - construction réelle des 36 fantômes et de la map avec la bibliothèque
	    @lune/roblox (vérifie que chaque propriété / Enum utilisé existe vraiment)
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Loader = require("./loader")
local loadModule = Loader.loadModule
local warnings = Loader.warnings

local passed, failed = 0, 0

local function check(condition: any, message: string)
	if condition then
		passed += 1
	else
		failed += 1
		print("ÉCHEC : " .. message)
	end
end

local SHARED = "src/ReplicatedStorage/Shared/"

---------------------------------------------------------------- Format
local Format = loadModule(SHARED .. "Format.luau")
check(Format.short(0) == "0", "Format 0")
check(Format.short(999) == "999", "Format 999")
check(Format.short(1000) == "1K", "Format 1000 -> " .. Format.short(1000))
check(Format.short(1234) == "1.23K", "Format 1234 -> " .. Format.short(1234))
check(Format.short(12345) == "12.3K", "Format 12345 -> " .. Format.short(12345))
check(Format.short(123456) == "123K", "Format 123456 -> " .. Format.short(123456))
check(Format.short(3400000) == "3.4M", "Format 3.4M -> " .. Format.short(3400000))
check(Format.short(2.5e9) == "2.5B", "Format 2.5B -> " .. Format.short(2.5e9))
check(Format.short(-1500) == "-1.5K", "Format négatif -> " .. Format.short(-1500))
check(Format.time(75) == "1:15", "Time 75 -> " .. Format.time(75))
check(Format.time(9) == "9s", "Time 9 -> " .. Format.time(9))
check(Format.time(-3) == "0s", "Time négatif")
check(Format.time(3725) == "1:02:05", "Time en heures -> " .. Format.time(3725))

---------------------------------------------------------------- Raretés
local Rarities = loadModule(SHARED .. "Rarities.luau")
check(Rarities.roll(0, false, false) == "Common", "roll(0) = Commun")
check(Rarities.roll(0.99999, false, false) == "Mythic", "roll(~1) de jour sans event = Mythique")
check(Rarities.roll(0.99999, true, true) == "Halloween", "roll(~1) la nuit pendant l'event = Halloween")
local sawHalloween = false
for i = 0, 1000 do
	if Rarities.roll(i / 1000, false, true) == "Halloween" then
		sawHalloween = true
	end
	if Rarities.roll(i / 1000, true, false) == "Halloween" then
		sawHalloween = true
	end
end
check(not sawHalloween, "Halloween seulement la nuit ET pendant l'event")

---------------------------------------------------------------- Fantômes
local GhostData = loadModule(SHARED .. "GhostData.luau")
check(#GhostData.List >= 25, "au moins 25 fantômes")
local ids = {}
local maxPrice = { Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 0 }
for _, ghost in GhostData.List do
	check(not ids[ghost.Id], "Id unique : " .. ghost.Id)
	ids[ghost.Id] = true
	check(string.match(ghost.Id, "^[%w]+$") ~= nil, "Id sans espace ni accent : " .. ghost.Id)
	check(Rarities.Info[ghost.Rarity] ~= nil, "rareté valide : " .. ghost.Id)
	check(ghost.Price > 0 and ghost.Income > 0, "prix et revenu > 0 : " .. ghost.Id)
	check(ghost.Name.fr and ghost.Name.en, "nom FR + EN : " .. ghost.Id)
	check(ghost.Gag.fr and ghost.Gag.en, "blague FR + EN : " .. ghost.Id)
	local payback = ghost.Price / ghost.Income
	check(payback >= 60 and payback <= 1500, string.format("rentabilisé en 1 à 25 min : %s (%.0f s)", ghost.Id, payback))
	if maxPrice[ghost.Rarity] then
		maxPrice[ghost.Rarity] = math.max(maxPrice[ghost.Rarity], ghost.Price)
	end
end
for _, rarity in Rarities.Order do
	check(GhostData.ByRarity[rarity] and #GhostData.ByRarity[rarity] > 0, "au moins un fantôme " .. rarity)
end
check(maxPrice.Common < maxPrice.Rare and maxPrice.Rare < maxPrice.Epic, "prix croissants Commun < Rare < Épique")
check(maxPrice.Epic < maxPrice.Legendary and maxPrice.Legendary < maxPrice.Mythic, "prix croissants Épique < Légendaire < Mythique")
check(GhostData.pick("Rare", 0.999).Rarity == "Rare", "pick respecte la rareté")

-- Variantes Dorée / Arc-en-ciel
local base, mut = GhostData.split("DrapMou#Gold")
check(base == "DrapMou" and mut == "Gold", "split d'une variante")
check(GhostData.split("DrapMou") == "DrapMou", "split sans variante")
check(GhostData.get("DrapMou#Gold") == GhostData.get("DrapMou"), "get ignore la variante")
check(GhostData.get("DrapMou#Platine") == nil, "variante inconnue refusée")
check(GhostData.get(nil :: any) == nil, "get(nil) ne plante pas")
check(GhostData.incomeOf("DrapMou#Gold") == GhostData.get("DrapMou").Income * 3, "Doré = revenu x3")
check(GhostData.priceOf("DrapMou#Rainbow") == GhostData.get("DrapMou").Price * 5, "Arc-en-ciel = prix x5")
check(GhostData.rollMutation(0.0001, false) == "Rainbow", "petit tirage = Arc-en-ciel")
check(GhostData.rollMutation(0.02, false) == "Gold", "tirage moyen = Doré")
check(GhostData.rollMutation(0.5, true) == nil, "la plupart du temps : pas de variante")
local mutated = 0
for i = 0, 9999 do
	if GhostData.rollMutation(i / 10000, false) then
		mutated += 1
	end
end
check(mutated >= 300 and mutated <= 400, "environ 3,6 % de variantes le jour (" .. mutated .. " sur 10 000)")
check(GhostData.key("DrapMou", nil) == "DrapMou" and GhostData.key("DrapMou", "Gold") == "DrapMou#Gold", "key")

local Config = loadModule(SHARED .. "Config.luau")
check(GhostData.get(Config.StarterGhost) ~= nil, "le fantôme de départ existe")
for day, reward in Config.DailyRewards do
	if reward.RandomGhostRarity then
		check(GhostData.ByRarity[reward.RandomGhostRarity] ~= nil, "rareté du cadeau jour " .. day)
	end
end
check(Config.HalloweenStart < Config.HalloweenEnd, "dates Halloween dans l'ordre")
for code, def in Config.Codes do
	check(string.match(code, "^[A-Z0-9]+$") ~= nil, "code en MAJUSCULES sans espace : " .. code)
	check(def.Coins or def.Minutes or def.Ghost, "le code donne quelque chose : " .. code)
	check(def.Ghost == nil or GhostData.get(def.Ghost) ~= nil, "fantôme du code existant : " .. code)
end
for _, rarity in Rarities.Order do
	check(type(Config.IndexRewards[rarity]) == "number", "récompense du Fantômédex pour " .. rarity)
end
check(Config.PedestalsPerFloor == 10 and Config.MaxPedestals == 20, "10 socles par étage, 20 au total")
check(Config.FloorPrice > 0, "prix de l'étage")

---------------------------------------------------------------- Missions du jour
local Missions = loadModule(SHARED .. "Missions.luau")
local m1 = Missions.generate(20373, 101, 10)
local m2 = Missions.generate(20373, 101, 10)
check(#m1 == 3, "3 missions par jour")
for i, tier in Missions.Tiers do
	check(m1[i].Tier == tier, "mission " .. i .. " de difficulté " .. tier)
	check(table.find(Missions.Pool[tier], m1[i].Id) ~= nil, "mission tirée dans la bonne liste (" .. m1[i].Id .. ")")
	check(m1[i].Id == m2[i].Id, "mêmes missions pour le même jour")
	check(m1[i].Target > 0 and m1[i].Progress == 0 and not m1[i].Done, "mission neuve")
end
local different = false
for day = 20374, 20390 do
	local other = Missions.generate(day, 101, 10)
	for i = 1, 3 do
		if other[i].Id ~= m1[i].Id then
			different = true
		end
	end
end
check(different, "les missions changent d'un jour à l'autre")
local seen = {}
for day = 20000, 20200 do
	for _, mission in Missions.generate(day, 7, 10) do
		seen[mission.Id] = true
	end
end
for _, tier in Missions.Tiers do
	for _, id in Missions.Pool[tier] do
		check(seen[id], "la mission " .. id .. " finit par tomber")
		check(Missions.Defs[id] ~= nil, "définition de la mission " .. id)
	end
end
check(Missions.earnTarget(0) == 500 and Missions.earnTarget(100) == 60000, "objectif 'Gagne X pièces'")
check(Missions.reward("hard", 0) == 1200 and Missions.reward("bonus", 100) == 60000, "récompenses des missions")

---------------------------------------------------------------- Textes FR / EN
local Strings = loadModule(SHARED .. "Strings.luau")
local function placeholders(text: string)
	local set = {}
	for name in string.gmatch(text, "{(%w+)}") do
		set[name] = true
	end
	return set
end
for key, fr in Strings.fr do
	local en = Strings.en[key]
	check(en ~= nil, "clé anglaise manquante : " .. key)
	if en then
		local a, b = placeholders(fr), placeholders(en)
		for name in a do
			check(b[name], string.format("paramètre {%s} manquant en anglais : %s", name, key))
		end
		for name in b do
			check(a[name], string.format("paramètre {%s} manquant en français : %s", name, key))
		end
	end
end
for key in Strings.en do
	check(Strings.fr[key] ~= nil, "clé française manquante : " .. key)
end
check(Strings.format("fr", "Sold", { coins = "1.2K" }) == "Vendu pour 1.2K pièces", "format de texte")
check(Strings.format("en", "AnnSteal", { thief = "A", ghost = "B", owner = "C" }) == "A stole B from C!", "format anglais")

-- Toutes les clés utilisées dans le code existent
local function scanKeys(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			scanKeys(path)
		elseif string.sub(name, -5) == ".luau" then
			local source = fs.readFile(path)
			for _, pattern in { 'notify%([^,]+,%s*"(%w+)"', 'announce%("(%w+)"', 'Lang%.t%("(%w+)"' } do
				for key in string.gmatch(source, pattern) do
					check(Strings.fr[key] ~= nil, "clé de texte inconnue '" .. key .. "' dans " .. path)
				end
			end
		end
	end
end
scanKeys("src")

---------------------------------------------------------------- Boutique, roue, armes, monstres
local Shop = loadModule(SHARED .. "Shop.luau")
local Wheel = loadModule(SHARED .. "Wheel.luau")
local Weapons = loadModule(SHARED .. "Weapons.luau")
local Monsters = loadModule(SHARED .. "Monsters.luau")

-- Roue : chances à 100 %, chaque case atteignable et utile (règles Roblox des objets aléatoires payants)
check(Wheel.totalChance() == 100, "les chances de la roue font 100 % (" .. Wheel.totalChance() .. ")")
check(Wheel.pick(0) == 1 and Wheel.pick(0.999999) == #Wheel.Segments, "tirage de la roue aux deux bouts")
local reached = {}
for i = 0, 9999 do
	reached[Wheel.pick(i / 10000)] = true
end
for index, segment in Wheel.Segments do
	check(reached[index], "case de la roue atteignable : " .. segment.Id)
	check(segment.Chance > 0, "chance positive : " .. segment.Id)
	check(Strings.fr["Wheel_" .. segment.Id] and Strings.en["Wheel_" .. segment.Id], "texte de la case : " .. segment.Id)
	check(Strings.fr["WheelShort_" .. segment.Id] and Strings.en["WheelShort_" .. segment.Id], "texte court de la case : " .. segment.Id)
	if segment.Kind == "Coins" then
		check(Wheel.coins(segment, 0) > 0, "une case de pièces donne toujours quelque chose : " .. segment.Id)
	elseif segment.Kind == "Ghost" then
		check(GhostData.ByRarity[segment.Rarity] ~= nil and #GhostData.ByRarity[segment.Rarity] > 0, "rareté de la case : " .. segment.Id)
		check(segment.Mutation == nil or GhostData.Mutations[segment.Mutation] ~= nil, "variante de la case : " .. segment.Id)
	elseif segment.Kind == "Boost" then
		check(segment.Seconds > 0 and Config.WheelBoostMult > 1, "boost de la roue")
	else
		check(false, "type de case inconnu : " .. tostring(segment.Kind))
	end
end
check(math.abs(Wheel.segmentAngle(1)) < 1e-9, "la case 1 est en haut")

-- Boutique : chaque article a un ID dans Config, un nom et ce qu'il faut pour être donné
for _, item in Shop.Items do
	local ids = if item.Kind == "Pass" then Config.GamePasses else Config.Products
	check(ids[item.Key] ~= nil, "ID prévu dans Config pour " .. item.Key)
	check(item.Robux and item.Robux > 0, "prix conseillé pour " .. item.Key)
	if item.Weapon then
		local weapon = Weapons.get(item.Weapon)
		check(weapon ~= nil and weapon.Pass == item.Key and not weapon.Free, "arme liée à son Game Pass : " .. item.Key)
		check(item.Attribute == "Weapon_" .. item.Weapon, "attribut de l'arme : " .. item.Key)
	elseif item.Monster then
		local monster = Monsters.get(item.Monster)
		check(monster ~= nil and monster.Product == item.Key, "monstre lié à son produit : " .. item.Key)
	else
		check(item.Name and item.Name.fr and item.Name.en and item.Desc, "nom et description : " .. item.Key)
	end
	if item.Kind == "Pass" then
		check(type(item.Attribute) == "string", "attribut du Game Pass : " .. item.Key)
	end
	check(not item.Random or item.Category == "Wheel", "seuls les tours de roue sont aléatoires : " .. item.Key)
end
for key in Config.GamePasses do
	check(Shop.get(key) ~= nil, "Game Pass de Config connu de la boutique : " .. key)
end
for key in Config.Products do
	check(Shop.get(key) ~= nil, "produit de Config connu de la boutique : " .. key)
end
for _, category in Shop.Categories do
	local count = 0
	for _, item in Shop.Items do
		if item.Category == category.Id then
			count += 1
		end
	end
	check(count > 0, "onglet de boutique non vide : " .. category.Id)
end

-- Armes : la batte est offerte, les autres sont des Game Passes, et l'outil se construit
local freeCount = 0
for _, weapon in Weapons.List do
	if weapon.Free then
		freeCount += 1
	end
	check(weapon.Range > 0 and weapon.Cooldown > 0 and weapon.Stun > 0, "réglages de l'arme : " .. weapon.Id)
	check(weapon.Name.fr and weapon.Name.en and weapon.Desc.fr and weapon.Desc.en, "textes de l'arme : " .. weapon.Id)
	check(weapon.Free or Shop.get(weapon.Pass) ~= nil, "Game Pass de l'arme dans la boutique : " .. weapon.Id)
	local tool = Weapons.buildTool(weapon.Id)
	check(tool:IsA("Tool") and tool:FindFirstChild("Handle") ~= nil, "outil avec poignée : " .. weapon.Id)
	check(tool:GetAttribute("WeaponId") == weapon.Id, "outil marqué : " .. weapon.Id)
	local parts, welded = 0, 0
	for _, d in tool:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Handle" then
			parts += 1
			check(not d.Anchored and not d.CanCollide, "pièce d'arme libre et sans collision : " .. weapon.Id)
			if d:FindFirstChildOfClass("WeldConstraint") then
				welded += 1
			end
		end
	end
	check(parts > 0 and welded == parts, "toutes les pièces sont soudées à la poignée : " .. weapon.Id)
end
check(freeCount == 1 and Weapons.ById.Batte.Free, "seule la batte est offerte")

-- Monstres : modèles et réglages
for _, monster in Monsters.List do
	check(monster.Speed > 0 and monster.CatchRange > 0 and monster.Duration > 0, "réglages du monstre : " .. monster.Id)
	local model = Monsters.build(monster.Id)
	check(model.PrimaryPart ~= nil and model.Name == monster.Id, "modèle du monstre : " .. monster.Id)
	local count = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
			check(d.Anchored and not d.CanCollide, "pièce de monstre ancrée sans collision : " .. monster.Id)
		end
	end
	check(count <= 60, monster.Id .. " : " .. count .. " pièces (max 60)")
end

-- Roue 3D : 8 cases, chaque case a son support de texte
local wheelModel = Wheel.build(nil)
local labels = 0
for _, d in wheelModel:GetDescendants() do
	if d:GetAttribute("Segment") then
		labels += 1
	end
end
check(labels == #Wheel.Segments, "un texte par case sur la roue 3D")

---------------------------------------------------------------- Remotes
local remoteSource = fs.readFile(SHARED .. "Remotes.luau")
local remoteNames = {}
for name in string.gmatch(remoteSource, '\n\t"(%w+)",') do
	check(not remoteNames[name], "Remote unique : " .. name)
	remoteNames[name] = true
end
local function scanRemotes(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			scanRemotes(path)
		elseif string.sub(name, -5) == ".luau" then
			for remote in string.gmatch(fs.readFile(path), 'Remotes%.get%("(%w+)"%)') do
				check(remoteNames[remote], "Remote inconnu '" .. remote .. "' dans " .. path)
			end
		end
	end
end
scanRemotes("src")

---------------------------------------------------------------- Construction des fantômes
local GhostFactory = loadModule(SHARED .. "GhostFactory.luau")
local totalParts = 0
for _, ghost in GhostData.List do
	local ok, result = pcall(GhostFactory.build, ghost.Id)
	check(ok, "construction de " .. ghost.Id .. " : " .. tostring(result))
	if ok then
		local model = result
		local parts = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
				check(d.Anchored and not d.CanCollide, ghost.Id .. " : pièce ancrée et sans collision")
			end
		end
		totalParts += parts
		check(parts <= 36, string.format("%s : %d pièces (max 36)", ghost.Id, parts))
		check(model.PrimaryPart ~= nil and model.PrimaryPart.Name == "Root", ghost.Id .. " a une racine")
		check(model:GetAttribute("GhostId") == ghost.Id, ghost.Id .. " attribut GhostId")
		check((model:GetAttribute("Bottom") or 0) > 0, ghost.Id .. " attribut Bottom")
	end
end
print(string.format("Pièces par fantôme en moyenne : %.1f", totalParts / #GhostData.List))
for _, key in { "DrapMou#Gold", "SpectroPizzaSupreme#Rainbow", "ChampignonChuchoteur#Gold" } do
	local ok, model = pcall(GhostFactory.build, key)
	check(ok, "construction de la variante " .. key .. " : " .. tostring(model))
	if ok then
		check(model:GetAttribute("GhostId") == key, key .. " garde sa variante")
		check(model.PrimaryPart:FindFirstChild("MutationSparkles") ~= nil, key .. " brille")
	end
end

---------------------------------------------------------------- Construction de la map
local MapBuilder = loadModule("src/ServerScriptService/Services/MapBuilder.luau")
local okMap, mapOrErr = pcall(MapBuilder.build)
check(okMap, "construction de la map : " .. tostring(mapOrErr))
if okMap then
	local map = mapOrErr
	local bases = map:FindFirstChild("Bases")
	check(bases and #bases:GetChildren() == Config.BaseCount, "12 bases")
	local mapParts = 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			mapParts += 1
		end
	end
	print("Pièces dans la map : " .. mapParts)
	check(mapParts < 2500, "map légère (< 2500 pièces)")
	if bases then
		local origins = {}
		for _, base in bases:GetChildren() do
			local pedestals = base:FindFirstChild("Pedestals")
			check(pedestals and #pedestals:GetChildren() == 20, base.Name .. " a 20 socles (2 étages)")
			check(base:FindFirstChild("Spawn") and base:FindFirstChild("LockButton") and base:FindFirstChild("Sign") and base:FindFirstChild("Mat"), base.Name .. " complet")
			check(base:FindFirstChild("UpPad") and base:FindFirstChild("Floor2") and base:FindFirstChild("LockStation"), base.Name .. " : ascenseur, étage, poste de verrou")
			local hidden = true
			for _, d in base.Floor2:GetDescendants() do
				if d:IsA("BasePart") and (d.Transparency < 1 or d.CanCollide) then
					hidden = false
				end
			end
			check(hidden, base.Name .. " : étage 2 caché au départ")
			-- les plaques au sol (récolte, ascenseur, verrou) ne se chevauchent pas
			local origin2 = base:GetAttribute("Origin")
			local rects = {}
			local function addRect(p: BasePart)
				local c = origin2:PointToObjectSpace(p.CFrame.Position)
				if c.Y < 3 then
					table.insert(rects, { name = p.Name, x0 = c.X - p.Size.X / 2, x1 = c.X + p.Size.X / 2, z0 = c.Z - p.Size.Z / 2, z1 = c.Z + p.Size.Z / 2 })
				end
			end
			addRect(base.UpPad)
			local lock = base.LockButton
			local lc = origin2:PointToObjectSpace(lock.CFrame.Position)
			table.insert(rects, { name = "LockButton", x0 = lc.X - 2, x1 = lc.X + 2, z0 = lc.Z - 2, z1 = lc.Z + 2 })
			for _, ped in base.Pedestals:GetChildren() do
				addRect(ped.CollectPad)
			end
			for i = 1, #rects do
				for j = i + 1, #rects do
					local a, b = rects[i], rects[j]
					local overlap = a.x0 < b.x1 and b.x0 < a.x1 and a.z0 < b.z1 and b.z0 < a.z1
					check(not overlap, base.Name .. " : " .. a.name .. " et " .. b.name .. " ne se chevauchent pas")
				end
			end
			if pedestals then
				for _, ped in pedestals:GetChildren() do
					local slot = ped:GetAttribute("Slot")
					local cf = ped:GetAttribute("GhostCFrame")
					local localLook = base:GetAttribute("Origin"):VectorToObjectSpace(cf.LookVector)
					local localPos = base:GetAttribute("Origin"):PointToObjectSpace(cf.Position)
					-- les fantômes regardent l'allée centrale
					check(localLook.X * localPos.X < 0 and math.abs(localLook.X) > 0.99, base.Name .. " socle " .. slot .. " tourné vers l'allée")
					check(ped:FindFirstChild("CollectPad") ~= nil, base.Name .. " socle " .. slot .. " a sa plaque")
					local expectedSide = if (slot - 1) % 10 < 5 then -1 else 1
					check(math.sign(localPos.X) == expectedSide, base.Name .. " socle " .. slot .. " du bon côté (5 à gauche, 5 à droite)")
				end
			end
			local origin = base:GetAttribute("Origin")
			check(typeof(origin) == "CFrame", base.Name .. " a une origine")
			table.insert(origins, origin.Position)
			-- l'avant de la base (-Z local) doit pointer vers le chemin (z = 0)
			local front = origin:PointToWorldSpace(roblox.Vector3.new(0, 0, -20))
			check(math.abs(front.Z) < math.abs(origin.Position.Z), base.Name .. " : entrée tournée vers le chemin")
			check(math.abs(front.Z) > 7, base.Name .. " : entrée hors du chemin")
		end
		for i = 1, #origins do
			for j = i + 1, #origins do
				local d = origins[i] - origins[j]
				check(math.abs(d.X) >= MapBuilder.BASE_WIDTH + 4 or math.abs(d.Z) >= MapBuilder.BASE_DEPTH + 4, "bases séparées")
			end
		end
	end
end

for _, w in warnings do
	print("AVERTISSEMENT : " .. w)
end
check(#warnings == 0, "aucun avertissement pendant les tests")

print(string.format("\n%d tests réussis, %d échoués", passed, failed))
if failed > 0 then
	process.exit(1)
end
