--[[
	Shop : tout ce qui s'achète avec des Robux (partagé serveur + joueurs).

	Pass = Game Pass (acheté une fois, gardé pour toujours) : son ID va dans Config.GamePasses
	Product = Developer Product (peut s'acheter plusieurs fois) : son ID va dans Config.Products
	Robux = prix conseillé, à reprendre quand tu crées l'article sur le Creator Hub.

	Tant qu'un ID vaut 0 :
	  - dans Studio, le bouton d'achat donne l'article gratuitement (pour tester)
	  - dans le vrai jeu, l'article affiche "Bientôt"
]]

local Shop = {}

Shop.Categories = {
	{ Id = "Passes", Icon = "⭐", Name = { fr = "Passes", en = "Passes" } },
	{ Id = "Weapons", Icon = "⚔️", Name = { fr = "Armes", en = "Weapons" } },
	{ Id = "Wheel", Icon = "🎡", Name = { fr = "Roue", en = "Wheel" } },
	{ Id = "Monsters", Icon = "👹", Name = { fr = "Monstres", en = "Monsters" } },
	{ Id = "Coins", Icon = "🪙", Name = { fr = "Pièces", en = "Coins" } },
}

Shop.Items = {
	-- Passes
	{
		Key = "DoubleCoins",
		Kind = "Pass",
		Category = "Passes",
		Icon = "💰",
		Robux = 149,
		Attribute = "DoubleCoins",
		Name = { fr = "x2 Pièces", en = "x2 Coins" },
		Desc = { fr = "Double tous tes revenus, pour toujours", en = "Double all your income, forever" },
	},
	-- Armes (les infos viennent de Weapons.luau)
	{ Key = "WeaponHammer", Kind = "Pass", Category = "Weapons", Weapon = "MarteauPouet", Robux = 99, Attribute = "Weapon_MarteauPouet" },
	{ Key = "WeaponBroom", Kind = "Pass", Category = "Weapons", Weapon = "BalaiSorciere", Robux = 149, Attribute = "Weapon_BalaiSorciere" },
	{ Key = "WeaponVacuum", Kind = "Pass", Category = "Weapons", Weapon = "AspiraFantome", Robux = 199, Attribute = "Weapon_AspiraFantome" },
	-- Tours de roue (objets aléatoires payants : chances affichées avant l'achat)
	{
		Key = "Spin1",
		Kind = "Product",
		Category = "Wheel",
		Icon = "🎡",
		Robux = 25,
		Spins = 1,
		Random = true,
		Name = { fr = "1 tour de roue", en = "1 wheel spin" },
		Desc = { fr = "Chaque case fait gagner quelque chose", en = "Every slot wins something" },
	},
	{
		Key = "Spin5",
		Kind = "Product",
		Category = "Wheel",
		Icon = "🎡",
		Robux = 99,
		Spins = 5,
		Random = true,
		Name = { fr = "5 tours de roue", en = "5 wheel spins" },
		Desc = { fr = "1 tour offert par rapport à 5 x 1", en = "1 free spin compared to 5 x 1" },
	},
	-- Monstres (les infos viennent de Monsters.luau)
	{ Key = "MonsterGloutrouille", Kind = "Product", Category = "Monsters", Monster = "Gloutrouille", Robux = 39 },
	{ Key = "MonsterBat", Kind = "Product", Category = "Monsters", Monster = "ChauveSourisTurbo", Robux = 59 },
	{ Key = "MonsterSpider", Kind = "Product", Category = "Monsters", Monster = "MamieToile", Robux = 79 },
	-- Pièces
	{
		Key = "CoinPack",
		Kind = "Product",
		Category = "Coins",
		Icon = "🪙",
		Robux = 25,
		Name = { fr = "Pack de pièces", en = "Coin pack" },
		Desc = { fr = "{coins} pièces tout de suite", en = "{coins} coins right now" },
	},
}

Shop.ByKey = {}
for order, item in Shop.Items do
	item.Order = order
	Shop.ByKey[item.Key] = item
end

function Shop.get(key: any)
	return if type(key) == "string" then Shop.ByKey[key] else nil
end

-- L'ID Roblox de l'article (0 = pas encore créé)
function Shop.idOf(item, config): number
	local list = if item.Kind == "Pass" then config.GamePasses else config.Products
	return tonumber(list[item.Key]) or 0
end

-- Retrouve l'article à partir d'un ID Roblox
function Shop.fromId(kind: string, id: number, config)
	if id == 0 then
		return nil
	end
	for _, item in Shop.Items do
		if item.Kind == kind and Shop.idOf(item, config) == id then
			return item
		end
	end
	return nil
end

return Shop
