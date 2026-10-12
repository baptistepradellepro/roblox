--[[
	GhostData : la liste des 36 fantômes du jeu (tous inventés), et leurs variantes Dorée et Arc-en-ciel.

	Pour chaque fantôme :
	  Id       : nom interne (sans espace ni accent, ne JAMAIS le changer après publication)
	  Rarity   : Common, Rare, Epic, Legendary, Mythic ou Halloween
	  Price    : prix d'achat en pièces
	  Income   : pièces gagnées par seconde quand il est posé sur un socle
	  Name     : nom affiché en français (fr) et en anglais (en)
	  Gag      : petite blague affichée dans la fiche du fantôme
	  Look     : apparence 3D (voir GhostFactory)
]]

local GhostData = {}

GhostData.List = {
	-- ===================== COMMUNS =====================
	{
		Id = "DrapMou", Rarity = "Common", Price = 20, Income = 1,
		Name = { fr = "Drap Mou", en = "Floppy Sheet" },
		Gag = { fr = "A oublié comment flotter.", en = "Forgot how to float." },
		Look = { Body = "Sheet", Color = { 245, 245, 250 }, Face = "Sleepy", Accessories = {} },
	},
	{
		Id = "ChaussetteOrpheline", Rarity = "Common", Price = 30, Income = 1,
		Name = { fr = "Chaussette Orpheline", en = "Lonely Sock" },
		Gag = { fr = "Cherche sa jumelle depuis 1987.", en = "Looking for its twin since 1987." },
		Look = { Body = "Sock", Color = { 120, 200, 255 }, Accent = { 255, 90, 90 }, Face = "Sad", Accessories = {} },
	},
	{
		Id = "TartineBoudeuse", Rarity = "Common", Price = 55, Income = 2,
		Name = { fr = "Tartine Boudeuse", en = "Grumpy Toast" },
		Gag = { fr = "Tombée côté confiture. Ne s'en remet pas.", en = "Landed jam side down. Still upset." },
		Look = { Body = "Block", Size = { 3.6, 3.6, 1 }, Color = { 222, 170, 100 }, Accent = { 200, 40, 70 }, Face = "Angry", Accessories = { "Jam" } },
	},
	{
		Id = "BouhBouhTimide", Rarity = "Common", Price = 65, Income = 2,
		Name = { fr = "Bouh-Bouh le Timide", en = "Shy Boo-Boo" },
		Gag = { fr = "Se fait peur tout seul.", en = "Scares himself." },
		Look = { Body = "Blob", Color = { 230, 235, 255 }, Face = "Shy", Accessories = {} },
	},
	{
		Id = "MamieCourantDair", Rarity = "Common", Price = 80, Income = 3,
		Name = { fr = "Mamie Courant d'Air", en = "Granny Draft" },
		Gag = { fr = "Ferme les portes derrière toi. Fort.", en = "Slams doors behind you. Loudly." },
		Look = { Body = "Sheet", Color = { 225, 240, 255 }, Accent = { 170, 170, 180 }, Face = "Happy", Accessories = { "Bun" } },
	},
	{
		Id = "GobeMiettes", Rarity = "Common", Price = 95, Income = 3,
		Name = { fr = "Gobe-Miettes", en = "Crumb Gobbler" },
		Gag = { fr = "Mange les miettes sous ton canapé.", en = "Eats the crumbs under your couch." },
		Look = { Body = "Blob", Color = { 255, 240, 200 }, Accent = { 160, 110, 60 }, Face = "BigMouth", Accessories = { "Crumbs" } },
	},
	{
		Id = "SpectreSpaghetti", Rarity = "Common", Price = 110, Income = 4,
		Name = { fr = "Spectre Spaghetti", en = "Spaghetti Spook" },
		Gag = { fr = "Toujours un peu trop cuit.", en = "Always a bit overcooked." },
		Look = { Body = "Sheet", Color = { 255, 225, 130 }, Accent = { 200, 60, 40 }, Face = "Happy", Accessories = { "Spaghetti" } },
	},
	{
		Id = "FantomePasFini", Rarity = "Common", Price = 125, Income = 4,
		Name = { fr = "Fantôme Pas Fini", en = "Unfinished Ghost" },
		Gag = { fr = "Encore en chargement... 99 %.", en = "Still loading... 99%." },
		Look = { Body = "Sheet", Color = { 190, 190, 200 }, Accent = { 80, 255, 255 }, Face = "Blank", Transparency = 0.35, Accessories = { "LoadingRing" } },
	},
	{
		Id = "FeuilleMorteRaleuse", Rarity = "Common", Price = 100, Income = 3,
		Name = { fr = "Feuille Morte Râleuse", en = "Grumpy Dead Leaf" },
		Gag = { fr = "Tombée de l'arbre. Elle ne l'a pas digéré.", en = "Fell off the tree. Still mad about it." },
		Look = { Body = "Leaf", Color = { 230, 110, 30 }, Accent = { 120, 60, 25 }, Face = "Angry", FaceScale = 0.85, Accessories = {} },
	},

	-- ===================== RARES =====================
	{
		Id = "Caquetome", Rarity = "Rare", Price = 450, Income = 7,
		Name = { fr = "Caquetôme", en = "Cluck-a-Boo" },
		Gag = { fr = "Pond des œufs invisibles.", en = "Lays invisible eggs." },
		Look = { Body = "Blob", Color = { 255, 255, 255 }, Accent = { 230, 40, 40 }, Face = "Shocked", Accessories = { "ChickenComb" } },
	},
	{
		Id = "FrigoFrisson", Rarity = "Rare", Price = 560, Income = 8,
		Name = { fr = "Frigo-Frisson", en = "Fridge Fright" },
		Gag = { fr = "S'ouvre tout seul à 3 h du matin.", en = "Opens by itself at 3 a.m." },
		Look = { Body = "Block", Size = { 3, 4.6, 2.4 }, Color = { 205, 235, 255 }, Accent = { 140, 150, 165 }, Face = "Shocked", Accessories = { "FridgeHandle" } },
	},
	{
		Id = "BrocoliBouh", Rarity = "Rare", Price = 640, Income = 10,
		Name = { fr = "Brocoli Bouh", en = "Broccoli Boo" },
		Gag = { fr = "Le seul légume qui fait peur aux parents.", en = "The only veggie that scares parents." },
		Look = { Body = "Cloud", Color = { 80, 170, 70 }, Accent = { 160, 210, 120 }, Face = "Happy", Accessories = { "Stalk" } },
	},
	{
		Id = "PantouflePossedee", Rarity = "Rare", Price = 770, Income = 11,
		Name = { fr = "Pantoufle Possédée", en = "Possessed Slipper" },
		Gag = { fr = "Disparaît quand tu la cherches.", en = "Vanishes when you need it." },
		Look = { Body = "Block", Size = { 2.6, 1.6, 4.2 }, Color = { 255, 150, 200 }, Accent = { 255, 255, 255 }, Face = "Angry", FaceScale = 0.6, Accessories = { "Pompom" } },
	},
	{
		Id = "SpatuleErrante", Rarity = "Rare", Price = 900, Income = 13,
		Name = { fr = "Spatule Errante", en = "Wandering Spatula" },
		Gag = { fr = "Retourne les crêpes... et les gens.", en = "Flips pancakes... and people." },
		Look = { Body = "Block", Size = { 2.8, 3, 0.5 }, Color = { 255, 120, 40 }, Accent = { 150, 100, 60 }, Face = "Happy", Accessories = { "Handle" } },
	},
	{
		Id = "NuageGrognon", Rarity = "Rare", Price = 1100, Income = 16,
		Name = { fr = "Nuage Grognon", en = "Grumpy Cloud" },
		Gag = { fr = "Il pleut seulement sur toi.", en = "It only rains on you." },
		Look = { Body = "Cloud", Color = { 150, 155, 170 }, Accent = { 90, 160, 255 }, Face = "Angry", Accessories = { "Rain" } },
	},
	{
		Id = "WifiFantome", Rarity = "Rare", Price = 1250, Income = 18,
		Name = { fr = "Wifi-Fantôme", en = "Wi-Fi Ghost" },
		Gag = { fr = "Coupe la connexion quand tu gagnes.", en = "Cuts your connection when you win." },
		Look = { Body = "Sheet", Color = { 120, 255, 200 }, Accent = { 40, 255, 120 }, Face = "Cool", Accessories = { "Antenna" } },
	},
	{
		Id = "ChampignonChuchoteur", Rarity = "Rare", Price = 950, Income = 14,
		Name = { fr = "Champignon Chuchoteur", en = "Whispering Mushroom" },
		Gag = { fr = "Raconte des secrets aux racines.", en = "Tells secrets to the roots." },
		Look = { Body = "Mushroom", Color = { 230, 50, 60 }, Accent = { 250, 240, 215 }, Face = "Shy", FaceScale = 0.6, Accessories = {} },
	},

	-- ===================== ÉPIQUES =====================
	{
		Id = "CrepeFrisson", Rarity = "Epic", Price = 6500, Income = 50,
		Name = { fr = "Crêpe-Frisson", en = "Creepy Crêpe" },
		Gag = { fr = "Sauté trop haut, jamais retombé.", en = "Flipped too high, never came down." },
		Look = { Body = "Disc", Color = { 240, 190, 110 }, Accent = { 255, 255, 255 }, Face = "Happy", Accessories = { "ChefHat" } },
	},
	{
		Id = "SirBougieFondue", Rarity = "Epic", Price = 8000, Income = 60,
		Name = { fr = "Sir Bougie Fondue", en = "Sir Melty Candle" },
		Gag = { fr = "Très distingué. Un peu coulant.", en = "Very posh. A bit drippy." },
		Look = { Body = "Tube", Size = { 2.6, 3.8 }, Color = { 255, 245, 220 }, Accent = { 255, 150, 30 }, Face = "Monocle", Accessories = { "Flame" } },
	},
	{
		Id = "Miaoufantome", Rarity = "Epic", Price = 9500, Income = 70,
		Name = { fr = "Miaoufantôme", en = "Meowghost" },
		Gag = { fr = "Fait tomber tes affaires de la table.", en = "Knocks your stuff off the table." },
		Look = { Body = "Sheet", Color = { 200, 180, 255 }, Accent = { 255, 160, 200 }, Face = "Cat", Accessories = { "CatEars" } },
	},
	{
		Id = "TornadeDeDraps", Rarity = "Epic", Price = 11000, Income = 85,
		Name = { fr = "Tornade de Draps", en = "Sheet Tornado" },
		Gag = { fr = "A pris la machine à laver trop au sérieux.", en = "Took the washing machine too seriously." },
		Look = { Body = "Tornado", Color = { 235, 240, 255 }, Accent = { 150, 200, 255 }, Face = "Dizzy", Accessories = {}, Spin = 4 },
	},
	{
		Id = "CapitaineCornichon", Rarity = "Epic", Price = 13500, Income = 100,
		Name = { fr = "Capitaine Cornichon", en = "Captain Gherkin" },
		Gag = { fr = "Navigue dans un bocal.", en = "Sails in a jar." },
		Look = { Body = "Tube", Size = { 2.4, 4.4 }, Color = { 90, 160, 60 }, Accent = { 30, 30, 35 }, Face = "Pirate", Accessories = { "Bumps", "PirateHat" } },
	},
	{
		Id = "Ballonfantome", Rarity = "Epic", Price = 15000, Income = 115,
		Name = { fr = "Ballonfantôme", en = "Balloon Boo" },
		Gag = { fr = "Éclate de rire. Littéralement.", en = "Bursts out laughing. Literally." },
		Look = { Body = "Blob", Color = { 255, 80, 90 }, Accent = { 255, 255, 255 }, Face = "Happy", Reflectance = 0.15, Accessories = { "String" } },
	},
	{
		Id = "MarronToutTremblant", Rarity = "Epic", Price = 12500, Income = 95,
		Name = { fr = "Marron Tout Tremblant", en = "Shivering Chestnut" },
		Gag = { fr = "A peur des écureuils. Avec raison.", en = "Scared of squirrels. Rightly so." },
		Look = { Body = "Blob", Color = { 125, 70, 40 }, Accent = { 215, 175, 120 }, Face = "Shocked", Accessories = { "Hilum" } },
	},

	-- ===================== LÉGENDAIRES =====================
	{
		Id = "RoiPatatome", Rarity = "Legendary", Price = 90000, Income = 420,
		Name = { fr = "Roi Patatôme", en = "King Spudghost" },
		Gag = { fr = "Règne sur toutes les frites du monde.", en = "Rules over every fry in the world." },
		Look = { Body = "Blob", Color = { 175, 125, 75 }, Accent = { 255, 200, 40 }, Face = "Happy", Accessories = { "Lumps", "Crown" } },
	},
	{
		Id = "DJBouhBoum", Rarity = "Legendary", Price = 130000, Income = 600,
		Name = { fr = "DJ Bouh-Boum", en = "DJ Boo-Boom" },
		Gag = { fr = "Ses basses font trembler les tombes.", en = "His bass shakes the graveyard." },
		Look = { Body = "Sheet", Color = { 70, 70, 110 }, Accent = { 0, 255, 220 }, Face = "Cool", Accessories = { "Headphones" } },
	},
	{
		Id = "BaronBiscotte", Rarity = "Legendary", Price = 170000, Income = 770,
		Name = { fr = "Baron Biscotte", en = "Baron Biscuit" },
		Gag = { fr = "Se brise en mille morceaux d'émotion.", en = "Crumbles with emotion." },
		Look = { Body = "Block", Size = { 3.4, 3.4, 1.2 }, Color = { 230, 180, 90 }, Accent = { 25, 25, 30 }, Face = "Monocle", Accessories = { "TopHat", "Mustache" } },
	},
	{
		Id = "GrandMereTurbo", Rarity = "Legendary", Price = 220000, Income = 1000,
		Name = { fr = "Grand-Mère Turbo", en = "Rocket Granny" },
		Gag = { fr = "0 à 100 km/h en 2 secondes. Avec ses biscuits.", en = "0 to 60 in 2 seconds. With cookies." },
		Look = { Body = "Sheet", Color = { 255, 230, 240 }, Accent = { 170, 170, 180 }, Face = "Happy", Accessories = { "Bun", "Rocket" } },
	},
	{
		Id = "EcureuilFantomeStresse", Rarity = "Legendary", Price = 150000, Income = 680,
		Name = { fr = "Écureuil Fantôme Stressé", en = "Stressed Ghost Squirrel" },
		Gag = { fr = "A caché ses noisettes en 1923. Les cherche encore.", en = "Hid his nuts in 1923. Still looking." },
		Look = { Body = "Sheet", Color = { 175, 115, 60 }, Accent = { 230, 190, 140 }, Face = "Shocked", Accessories = { "CatEars", "SquirrelTail" } },
	},

	-- ===================== MYTHIQUES =====================
	{
		Id = "MegaBouhCosmique", Rarity = "Mythic", Price = 1800000, Income = 5500,
		Name = { fr = "Méga Bouh Cosmique", en = "Cosmic Mega Boo" },
		Gag = { fr = "A fait peur à une galaxie entière.", en = "Once scared an entire galaxy." },
		Look = { Body = "Sheet", Color = { 60, 40, 150 }, Accent = { 255, 120, 255 }, Face = "Happy", Accessories = { "Rings" } },
	},
	{
		Id = "EmpereurDesChaussettes", Rarity = "Mythic", Price = 3000000, Income = 9000,
		Name = { fr = "Empereur des Chaussettes", en = "Sock Emperor" },
		Gag = { fr = "Toutes les chaussettes perdues finissent chez lui.", en = "Every lost sock ends up at his palace." },
		Look = { Body = "Sock", Color = { 255, 215, 80 }, Accent = { 200, 30, 50 }, Face = "Monocle", Accessories = { "Crown", "Cape" } },
	},
	{
		Id = "SpectroPizzaSupreme", Rarity = "Mythic", Price = 4500000, Income = 14000,
		Name = { fr = "Spectro-Pizza Suprême", en = "Supreme Spectro-Pizza" },
		Gag = { fr = "Livrée en 30 secondes ou elle te hante.", en = "Delivered in 30 seconds or it haunts you." },
		Look = { Body = "Pizza", Color = { 255, 205, 70 }, Accent = { 200, 40, 40 }, Face = "Happy", Accessories = { "Pepperoni" } },
	},

	-- ===================== HALLOWEEN (édition limitée) =====================
	{
		Id = "CitrouilleToupie", Rarity = "Halloween", Price = 400000, Income = 2000,
		Name = { fr = "Citrouille Toupie", en = "Spinning Pumpkin" },
		Gag = { fr = "Tourne tellement qu'elle fait de la soupe.", en = "Spins so fast it makes soup." },
		Look = { Body = "Blob", Color = { 255, 130, 20 }, Accent = { 60, 140, 40 }, Face = "JackO", Accessories = { "Stem" }, Spin = 6 },
	},
	{
		Id = "SorciereTrottinette", Rarity = "Halloween", Price = 520000, Income = 2600,
		Name = { fr = "Sorcière Trottinette", en = "Scooter Witch" },
		Gag = { fr = "Le balai, c'était trop lent.", en = "The broom was too slow." },
		Look = { Body = "Sheet", Color = { 170, 120, 230 }, Accent = { 40, 30, 50 }, Face = "Happy", Accessories = { "WitchHat", "Scooter" } },
	},
	{
		Id = "SqueletteDisco", Rarity = "Halloween", Price = 680000, Income = 3400,
		Name = { fr = "Squelette Disco", en = "Disco Skeleton" },
		Gag = { fr = "Danse jusqu'à l'os.", en = "Dances down to the bone." },
		Look = { Body = "Sheet", Color = { 240, 235, 220 }, Accent = { 220, 220, 255 }, Face = "Skull", Accessories = { "DiscoBall" } },
	},
	{
		Id = "BonbonHurleur", Rarity = "Halloween", Price = 850000, Income = 4200,
		Name = { fr = "Bonbon Hurleur", en = "Howling Candy" },
		Gag = { fr = "Crie quand on veut le manger.", en = "Screams when you try to eat it." },
		Look = { Body = "Candy", Color = { 255, 90, 180 }, Accent = { 255, 230, 120 }, Face = "Shocked", Accessories = {} },
	},
}

-- Accès rapide par Id : GhostData.ById.DrapMou
GhostData.ById = {}
-- Liste par rareté : GhostData.ByRarity.Rare = { ... }
GhostData.ByRarity = {}

for index, ghost in GhostData.List do
	ghost.Order = index
	GhostData.ById[ghost.Id] = ghost
	GhostData.ByRarity[ghost.Rarity] = GhostData.ByRarity[ghost.Rarity] or {}
	table.insert(GhostData.ByRarity[ghost.Rarity], ghost)
end

-- Variantes rares : un fantôme du chemin peut être Doré (x3) ou Arc-en-ciel (x5).
-- Elles multiplient le revenu ET le prix. Chance = de jour, NightChance = pendant la nuit.
GhostData.Mutations = {
	Gold = { Mult = 3, Chance = 0.03, NightChance = 0.06, Color = { 255, 200, 40 }, Name = { fr = "Doré", en = "Golden" } },
	Rainbow = { Mult = 5, Chance = 0.006, NightChance = 0.015, Color = { 255, 110, 230 }, Name = { fr = "Arc-en-ciel", en = "Rainbow" } },
}
GhostData.MutationOrder = { "Gold", "Rainbow" }

-- Un fantôme est noté "DrapMou" ou, s'il a une variante, "DrapMou#Gold".
-- split("DrapMou#Gold") -> "DrapMou", "Gold"
function GhostData.split(key: string): (string, string?)
	local base, mutation = string.match(key, "^(%w+)#(%w+)$")
	if base then
		return base, mutation
	end
	return key, nil
end

function GhostData.key(baseId: string, mutation: string?): string
	if mutation then
		return baseId .. "#" .. mutation
	end
	return baseId
end

-- Les infos du fantôme (sans la variante). Marche avec "DrapMou" comme avec "DrapMou#Gold".
function GhostData.get(key: string)
	if type(key) ~= "string" then
		return nil
	end
	local base, mutation = GhostData.split(key)
	if mutation and not GhostData.Mutations[mutation] then
		return nil
	end
	return GhostData.ById[base]
end

function GhostData.mutationOf(key: string)
	local _, mutation = GhostData.split(key)
	return mutation and GhostData.Mutations[mutation]
end

-- Revenu par seconde et prix, variante comprise
function GhostData.incomeOf(key: string): number
	local ghost = GhostData.get(key)
	local mutation = GhostData.mutationOf(key)
	return if ghost then ghost.Income * (if mutation then mutation.Mult else 1) else 0
end

function GhostData.priceOf(key: string): number
	local ghost = GhostData.get(key)
	local mutation = GhostData.mutationOf(key)
	return if ghost then ghost.Price * (if mutation then mutation.Mult else 1) else 0
end

-- Tire une variante au hasard (ou nil). roll = nombre entre 0 et 1.
function GhostData.rollMutation(roll: number, isNight: boolean, boost: number?): string?
	local acc = 0
	for i = #GhostData.MutationOrder, 1, -1 do
		local name = GhostData.MutationOrder[i]
		local m = GhostData.Mutations[name]
		acc += (if isNight then m.NightChance else m.Chance) * (boost or 1)
		if roll < acc then
			return name
		end
	end
	return nil
end

-- Choisit un fantôme au hasard dans une rareté. roll = nombre entre 0 et 1.
function GhostData.pick(rarity: string, roll: number)
	local list = GhostData.ByRarity[rarity]
	if not list or #list == 0 then
		list = GhostData.ByRarity.Common
	end
	local index = math.clamp(math.floor(roll * #list) + 1, 1, #list)
	return list[index]
end

return GhostData
