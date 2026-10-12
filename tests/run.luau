--[[
	Tests automatiques (hors Roblox) avec Lune : `lune run tests/run.luau`
	  - logique pure : formats, raretés, données des fantômes, textes FR/EN
	  - construction réelle des 32 fantômes et de la map avec la bibliothèque
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
	check(payback >= 10 and payback <= 200, string.format("rentabilisé en 10-200 s : %s (%.0f s)", ghost.Id, payback))
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
check(Config.StartPedestals <= Config.MaxPedestals and Config.MaxPedestals == 12, "nombre de socles")

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
		check(parts <= 32, string.format("%s : %d pièces (max 32)", ghost.Id, parts))
		check(model.PrimaryPart ~= nil and model.PrimaryPart.Name == "Root", ghost.Id .. " a une racine")
		check(model:GetAttribute("GhostId") == ghost.Id, ghost.Id .. " attribut GhostId")
		check((model:GetAttribute("Bottom") or 0) > 0, ghost.Id .. " attribut Bottom")
	end
end
print(string.format("Pièces par fantôme en moyenne : %.1f", totalParts / #GhostData.List))

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
			check(pedestals and #pedestals:GetChildren() == 12, base.Name .. " a 12 socles")
			check(base:FindFirstChild("Spawn") and base:FindFirstChild("LockButton") and base:FindFirstChild("Sign") and base:FindFirstChild("Mat"), base.Name .. " complet")
			local origin = base:GetAttribute("Origin")
			check(typeof(origin) == "CFrame", base.Name .. " a une origine")
			table.insert(origins, origin.Position)
			-- l'avant de la base (-Z local) doit pointer vers le chemin (z = 0)
			local front = origin:PointToWorldSpace(roblox.Vector3.new(0, 0, -16))
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
