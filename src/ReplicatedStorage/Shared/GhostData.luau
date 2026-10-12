--[[
	GhostData : la liste des 32 fantômes du jeu (tous inventés).

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
		Id = "DrapMou", Rarity = "Common", Price = 15, Income = 1,
		Name = { fr = "Drap Mou", en = "Floppy Sheet" },
		Gag = { fr = "A oublié comment flotter.", en = "Forgot how to float." },
		Look = { Body = "Sheet", Color = { 245, 245, 250 }, Face = "Sleepy", Accessories = {} },
	},
	{
		Id = "ChaussetteOrpheline", Rarity = "Common", Price = 20, Income = 1,
		Name = { fr = "Chaussette Orpheline", en = "Lonely Sock" },
		Gag = { fr = "Cherche sa jumelle depuis 1987.", en = "Looking for its twin since 1987." },
		Look = { Body = "Sock", Color = { 120, 200, 255 }, Accent = { 255, 90, 90 }, Face = "Sad", Accessories = {} },
	},
	{
		Id = "TartineBoudeuse", Rarity = "Common", Price = 30, Income = 2,
		Name = { fr = "Tartine Boudeuse", en = "Grumpy Toast" },
		Gag = { fr = "Tombée côté confiture. Ne s'en remet pas.", en = "Landed jam side down. Still upset." },
		Look = { Body = "Block", Size = { 3.6, 3.6, 1 }, Color = { 222, 170, 100 }, Accent = { 200, 40, 70 }, Face = "Angry", Accessories = { "Jam" } },
	},
	{
		Id = "BouhBouhTimide", Rarity = "Common", Price = 35, Income = 2,
		Name = { fr = "Bouh-Bouh le Timide", en = "Shy Boo-Boo" },
		Gag = { fr = "Se fait peur tout seul.", en = "Scares himself." },
		Look = { Body = "Blob", Color = { 230, 235, 255 }, Face = "Shy", Accessories = {} },
	},
	{
		Id = "MamieCourantDair", Rarity = "Common", Price = 40, Income = 3,
		Name = { fr = "Mamie Courant d'Air", en = "Granny Draft" },
		Gag = { fr = "Ferme les portes derrière toi. Fort.", en = "Slams doors behind you. Loudly." },
		Look = { Body = "Sheet", Color = { 225, 240, 255 }, Accent = { 170, 170, 180 }, Face = "Happy", Accessories = { "Bun" } },
	},
	{
		Id = "GobeMiettes", Rarity = "Common", Price = 45, Income = 3,
		Name = { fr = "Gobe-Miettes", en = "Crumb Gobbler" },
		Gag = { fr = "Mange les miettes sous ton canapé.", en = "Eats the crumbs under your couch." },
		Look = { Body = "Blob", Color = { 255, 240, 200 }, Accent = { 160, 110, 60 }, Face = "BigMouth", Accessories = { "Crumbs" } },
	},
	{
		Id = "SpectreSpaghetti", Rarity = "Common", Price = 55, Income = 4,
		Name = { fr = "Spectre Spaghetti", en = "Spaghetti Spook" },
		Gag = { fr = "Toujours un peu trop cuit.", en = "Always a bit overcooked." },
		Look = { Body = "Sheet", Color = { 255, 225, 130 }, Accent = { 200, 60, 40 }, Face = "Happy", Accessories = { "Spaghetti" } },
	},
	{
		Id = "FantomePasFini", Rarity = "Common", Price = 60, Income = 4,
		Name = { fr = "Fantôme Pas Fini", en = "Unfinished Ghost" },
		Gag = { fr = "Encore en chargement... 99 %.", en = "Still loading... 99%." },
		Look = { Body = "Sheet", Color = { 190, 190, 200 }, Accent = { 80, 255, 255 }, Face = "Blank", Transparency = 0.35, Accessories = { "LoadingRing" } },
	},

	-- ===================== RARES =====================
	{
		Id = "Caquetome", Rarity = "Rare", Price = 300, Income = 10,
		Name = { fr = "Caquetôme", en = "Cluck-a-Boo" },
		Gag = { fr = "Pond des œufs invisibles.", en = "Lays invisible eggs." },
		Look = { Body = "Blob", Color = { 255, 255, 255 }, Accent = { 230, 40, 40 }, Face = "Shocked", Accessories = { "ChickenComb" } },
	},
	{
		Id = "FrigoFrisson", Rarity = "Rare", Price = 380, Income = 12,
		Name = { fr = "Frigo-Frisson", en = "Fridge Fright" },
		Gag = { fr = "S'ouvre tout seul à 3 h du matin.", en = "Opens by itself at 3 a.m." },
		Look = { Body = "Block", Size = { 3, 4.6, 2.4 }, Color = { 205, 235, 255 }, Accent = { 140, 150, 165 }, Face = "Shocked", Accessories = { "FridgeHandle" } },
	},
	{
		Id = "BrocoliBouh", Rarity = "Rare", Price = 450, Income = 14,
		Name = { fr = "Brocoli Bouh", en = "Broccoli Boo" },
		Gag = { fr = "Le seul légume qui fait peur aux parents.", en = "The only veggie that scares parents." },
		Look = { Body = "Cloud", Color = { 80, 170, 70 }, Accent = { 160, 210, 120 }, Face = "Happy", Accessories = { "Stalk" } },
	},
	{
		Id = "PantouflePossedee", Rarity = "Rare", Price = 550, Income = 16,
		Name = { fr = "Pantoufle Possédée", en = "Possessed Slipper" },
		Gag = { fr = "Disparaît quand tu la cherches.", en = "Vanishes when you need it." },
		Look = { Body = "Block", Size = { 2.6, 1.6, 4.2 }, Color = { 255, 150, 200 }, Accent = { 255, 255, 255 }, Face = "Angry", FaceScale = 0.6, Accessories = { "Pompom" } },
	},
	{
		Id = "SpatuleErrante", Rarity = "Rare", Price = 650, Income = 18,
		Name = { fr = "Spatule Errante", en = "Wandering Spatula" },
		Gag = { fr = "Retourne les crêpes... et les gens.", en = "Flips pancakes... and people." },
		Look = { Body = "Block", Size = { 2.8, 3, 0.5 }, Color = { 255, 120, 40 }, Accent = { 150, 100, 60 }, Face = "Happy", Accessories = { "Handle" } },
	},
	{
		Id = "NuageGrognon", Rarity = "Rare", Price = 780, Income = 22,
		Name = { fr = "Nuage Grognon", en = "Grumpy Cloud" },
		Gag = { fr = "Il pleut seulement sur toi.", en = "It only rains on you." },
		Look = { Body = "Cloud", Color = { 150, 155, 170 }, Accent = { 90, 160, 255 }, Face = "Angry", Accessories = { "Rain" } },
	},
	{
		Id = "WifiFantome", Rarity = "Rare", Price = 900, Income = 25,
		Name = { fr = "Wifi-Fantôme", en = "Wi-Fi Ghost" },
		Gag = { fr = "Coupe la connexion quand tu gagnes.", en = "Cuts your connection when you win." },
		Look = { Body = "Sheet", Color = { 120, 255, 200 }, Accent = { 40, 255, 120 }, Face = "Cool", Accessories = { "Antenna" } },
	},

	-- ===================== ÉPIQUES =====================
	{
		Id = "CrepeFrisson", Rarity = "Epic", Price = 4000, Income = 70,
		Name = { fr = "Crêpe-Frisson", en = "Creepy Crêpe" },
		Gag = { fr = "Sauté trop haut, jamais retombé.", en = "Flipped too high, never came down." },
		Look = { Body = "Disc", Color = { 240, 190, 110 }, Accent = { 255, 255, 255 }, Face = "Happy", Accessories = { "ChefHat" } },
	},
	{
		Id = "SirBougieFondue", Rarity = "Epic", Price = 5200, Income = 85,
		Name = { fr = "Sir Bougie Fondue", en = "Sir Melty Candle" },
		Gag = { fr = "Très distingué. Un peu coulant.", en = "Very posh. A bit drippy." },
		Look = { Body = "Tube", Size = { 2.6, 3.8 }, Color = { 255, 245, 220 }, Accent = { 255, 150, 30 }, Face = "Monocle", Accessories = { "Flame" } },
	},
	{
		Id = "Miaoufantome", Rarity = "Epic", Price = 6500, Income = 100,
		Name = { fr = "Miaoufantôme", en = "Meowghost" },
		Gag = { fr = "Fait tomber tes affaires de la table.", en = "Knocks your stuff off the table." },
		Look = { Body = "Sheet", Color = { 200, 180, 255 }, Accent = { 255, 160, 200 }, Face = "Cat", Accessories = { "CatEars" } },
	},
	{
		Id = "TornadeDeDraps", Rarity = "Epic", Price = 8000, Income = 120,
		Name = { fr = "Tornade de Draps", en = "Sheet Tornado" },
		Gag = { fr = "A pris la machine à laver trop au sérieux.", en = "Took the washing machine too seriously." },
		Look = { Body = "Tornado", Color = { 235, 240, 255 }, Accent = { 150, 200, 255 }, Face = "Dizzy", Accessories = {}, Spin = 4 },
	},
	{
		Id = "CapitaineCornichon", Rarity = "Epic", Price = 10000, Income = 140,
		Name = { fr = "Capitaine Cornichon", en = "Captain Gherkin" },
		Gag = { fr = "Navigue dans un bocal.", en = "Sails in a jar." },
		Look = { Body = "Tube", Size = { 2.4, 4.4 }, Color = { 90, 160, 60 }, Accent = { 30, 30, 35 }, Face = "Pirate", Accessories = { "Bumps", "PirateHat" } },
	},
	{
		Id = "Ballonfantome", Rarity = "Epic", Price = 12000, Income = 160,
		Name = { fr = "Ballonfantôme", en = "Balloon Boo" },
		Gag = { fr = "Éclate de rire. Littéralement.", en = "Bursts out laughing. Literally." },
		Look = { Body = "Blob", Color = { 255, 80, 90 }, Accent = { 255, 255, 255 }, Face = "Happy", Reflectance = 0.15, Accessories = { "String" } },
	},

	-- ===================== LÉGENDAIRES =====================
	{
		Id = "RoiPatatome", Rarity = "Legendary", Price = 60000, Income = 600,
		Name = { fr = "Roi Patatôme", en = "King Spudghost" },
		Gag = { fr = "Règne sur toutes les frites du monde.", en = "Rules over every fry in the world." },
		Look = { Body = "Blob", Color = { 175, 125, 75 }, Accent = { 255, 200, 40 }, Face = "Happy", Accessories = { "Lumps", "Crown" } },
	},
	{
		Id = "DJBouhBoum", Rarity = "Legendary", Price = 85000, Income = 850,
		Name = { fr = "DJ Bouh-Boum", en = "DJ Boo-Boom" },
		Gag = { fr = "Ses basses font trembler les tombes.", en = "His bass shakes the graveyard." },
		Look = { Body = "Sheet", Color = { 70, 70, 110 }, Accent = { 0, 255, 220 }, Face = "Cool", Accessories = { "Headphones" } },
	},
	{
		Id = "BaronBiscotte", Rarity = "Legendary", Price = 115000, Income = 1100,
		Name = { fr = "Baron Biscotte", en = "Baron Biscuit" },
		Gag = { fr = "Se brise en mille morceaux d'émotion.", en = "Crumbles with emotion." },
		Look = { Body = "Block", Size = { 3.4, 3.4, 1.2 }, Color = { 230, 180, 90 }, Accent = { 25, 25, 30 }, Face = "Monocle", Accessories = { "TopHat", "Mustache" } },
	},
	{
		Id = "GrandMereTurbo", Rarity = "Legendary", Price = 150000, Income = 1400,
		Name = { fr = "Grand-Mère Turbo", en = "Rocket Granny" },
		Gag = { fr = "0 à 100 km/h en 2 secondes. Avec ses biscuits.", en = "0 to 60 in 2 seconds. With cookies." },
		Look = { Body = "Sheet", Color = { 255, 230, 240 }, Accent = { 170, 170, 180 }, Face = "Happy", Accessories = { "Bun", "Rocket" } },
	},

	-- ===================== MYTHIQUES =====================
	{
		Id = "MegaBouhCosmique", Rarity = "Mythic", Price = 1000000, Income = 8000,
		Name = { fr = "Méga Bouh Cosmique", en = "Cosmic Mega Boo" },
		Gag = { fr = "A fait peur à une galaxie entière.", en = "Once scared an entire galaxy." },
		Look = { Body = "Sheet", Color = { 60, 40, 150 }, Accent = { 255, 120, 255 }, Face = "Happy", Accessories = { "Rings" } },
	},
	{
		Id = "EmpereurDesChaussettes", Rarity = "Mythic", Price = 1800000, Income = 13000,
		Name = { fr = "Empereur des Chaussettes", en = "Sock Emperor" },
		Gag = { fr = "Toutes les chaussettes perdues finissent chez lui.", en = "Every lost sock ends up at his palace." },
		Look = { Body = "Sock", Color = { 255, 215, 80 }, Accent = { 200, 30, 50 }, Face = "Monocle", Accessories = { "Crown", "Cape" } },
	},
	{
		Id = "SpectroPizzaSupreme", Rarity = "Mythic", Price = 3000000, Income = 20000,
		Name = { fr = "Spectro-Pizza Suprême", en = "Supreme Spectro-Pizza" },
		Gag = { fr = "Livrée en 30 secondes ou elle te hante.", en = "Delivered in 30 seconds or it haunts you." },
		Look = { Body = "Pizza", Color = { 255, 205, 70 }, Accent = { 200, 40, 40 }, Face = "Happy", Accessories = { "Pepperoni" } },
	},

	-- ===================== HALLOWEEN (édition limitée) =====================
	{
		Id = "CitrouilleToupie", Rarity = "Halloween", Price = 250000, Income = 3000,
		Name = { fr = "Citrouille Toupie", en = "Spinning Pumpkin" },
		Gag = { fr = "Tourne tellement qu'elle fait de la soupe.", en = "Spins so fast it makes soup." },
		Look = { Body = "Blob", Color = { 255, 130, 20 }, Accent = { 60, 140, 40 }, Face = "JackO", Accessories = { "Stem" }, Spin = 6 },
	},
	{
		Id = "SorciereTrottinette", Rarity = "Halloween", Price = 350000, Income = 3800,
		Name = { fr = "Sorcière Trottinette", en = "Scooter Witch" },
		Gag = { fr = "Le balai, c'était trop lent.", en = "The broom was too slow." },
		Look = { Body = "Sheet", Color = { 170, 120, 230 }, Accent = { 40, 30, 50 }, Face = "Happy", Accessories = { "WitchHat", "Scooter" } },
	},
	{
		Id = "SqueletteDisco", Rarity = "Halloween", Price = 450000, Income = 4800,
		Name = { fr = "Squelette Disco", en = "Disco Skeleton" },
		Gag = { fr = "Danse jusqu'à l'os.", en = "Dances down to the bone." },
		Look = { Body = "Sheet", Color = { 240, 235, 220 }, Accent = { 220, 220, 255 }, Face = "Skull", Accessories = { "DiscoBall" } },
	},
	{
		Id = "BonbonHurleur", Rarity = "Halloween", Price = 600000, Income = 6000,
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

function GhostData.get(id: string)
	return GhostData.ById[id]
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
