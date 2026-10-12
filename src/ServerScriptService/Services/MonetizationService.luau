--[[
	MonetizationService : tout ce qui s'achète avec des Robux (liste dans Shop.luau).
	  - Game Passes : x2 Pièces et les armes (Marteau Pouet, Balai, Aspira-Fantôme)
	  - Developer Products : pack de pièces, tours de Roue de la Fortune, monstres à lâcher

	Le joueur clique sur "Acheter" : le serveur vérifie, puis ouvre la fenêtre Robux.
	Dans Studio, un article dont l'ID vaut 0 est donné gratuitement (pour tester).
	Les tours de roue sont des "objets aléatoires payants" : ils ne sont jamais proposés
	aux joueurs des pays où c'est interdit (PolicyService).
	Les armes servent seulement à défendre : rien n'aide à voler.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Shop = require(Shared:WaitForChild("Shop"))

local AnnounceService = require(script.Parent.AnnounceService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Guard = require(script.Parent.Guard)
local MonsterService = require(script.Parent.MonsterService)
local WeaponService = require(script.Parent.WeaponService)
local WheelService = require(script.Parent.WheelService)

local MonetizationService = {}

local IS_STUDIO = RunService:IsStudio()

-- Pour les tests (le simulateur hors Roblox fait comme Studio si on le lui demande)
MonetizationService.studioMode = IS_STUDIO

function MonetizationService.coinPackAmount(player: Player): number
	local perMinute = EconomyService.incomePerSecond(player) * 60
	return math.max(Config.CoinPackMin, math.floor(perMinute * Config.CoinPackMinutes))
end

-- Les objets aléatoires payants sont-ils interdits pour ce joueur ?
local function checkRandomItems(player: Player)
	if MonetizationService.studioMode then
		player:SetAttribute("RandomItemsRestricted", false)
		return
	end
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	-- en cas de doute (erreur), on bloque : c'est la règle la plus sûre
	local restricted = not ok or type(info) ~= "table" or info.ArePaidRandomItemsRestricted ~= false
	player:SetAttribute("RandomItemsRestricted", restricted)
end

---------------------------------------------------------------- Donner les articles

local function grantPass(player: Player, item)
	player:SetAttribute(item.Attribute, true)
	if item.Weapon then
		WeaponService.onPassOwned(player)
	end
	EconomyService.refresh(player)
end

-- Donne un Developer Product. Renvoie true si c'est fait.
local function grantProduct(player: Player, item): boolean
	if item.Key == "CoinPack" then
		EconomyService.add(player, MonetizationService.coinPackAmount(player))
		return true
	elseif item.Spins then
		WheelService.addSpins(player, item.Spins)
		return true
	elseif item.Monster then
		return MonsterService.summon(player, item.Monster)
	end
	return false
end

local function thanks(player: Player)
	AnnounceService.notify(player, "ShopThanks", nil, "good")
	AnnounceService.effect("Gift", {}, player)
end

---------------------------------------------------------------- Achats

local function onShopBuy(player: Player, key: any)
	if not Guard.rate(player, "ShopBuy", 0.5) then
		return
	end
	local item = Shop.get(key)
	if not item then
		return
	end
	if item.Random and player:GetAttribute("RandomItemsRestricted") then
		AnnounceService.notify(player, "ShopRestricted", nil, "bad")
		return
	end
	if item.Kind == "Pass" and player:GetAttribute(item.Attribute) then
		AnnounceService.notify(player, "ShopOwned", nil, "info")
		return
	end
	local id = Shop.idOf(item, Config)
	if id == 0 then
		if MonetizationService.studioMode then
			-- mode test de Studio : gratuit
			if item.Kind == "Pass" then
				grantPass(player, item)
			else
				grantProduct(player, item)
			end
			AnnounceService.notify(player, "ShopStudioFree", nil, "info")
			AnnounceService.effect("Gift", {}, player)
		else
			AnnounceService.notify(player, "ShopSoon", nil, "info")
		end
		return
	end
	local ok, err = pcall(function()
		if item.Kind == "Pass" then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
	if not ok then
		warn("[Monetization] Fenêtre d'achat impossible : " .. tostring(err))
	end
end

-- Achat d'un Developer Product : Roblox rappelle cette fonction jusqu'à ce qu'on
-- réponde "PurchaseGranted". On note chaque achat pour ne jamais créditer deux fois.
local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(data.Receipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local item = Shop.fromId("Product", receipt.ProductId, Config)
	if not item then
		warn("[Monetization] Produit inconnu : " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not grantProduct(player, item) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(data.Receipts, receipt.PurchaseId)
	while #data.Receipts > 50 do
		table.remove(data.Receipts, 1)
	end
	thanks(player)
	-- on sauvegarde tout de suite ; si ça échoue, Roblox réessaiera plus tard
	if DataService.save(player, false) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Vérifie les Game Passes et les règles du pays à l'arrivée du joueur
function MonetizationService.setup(player: Player)
	checkRandomItems(player)
	for _, item in Shop.Items do
		if item.Kind == "Pass" then
			local passId = Shop.idOf(item, Config)
			if passId ~= 0 then
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
				end)
				if ok and owns then
					player:SetAttribute(item.Attribute, true)
				end
			end
		end
	end
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	Remotes.get("ShopBuy").OnServerEvent:Connect(onShopBuy)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local item = Shop.fromId("Pass", passId, Config)
		if item then
			grantPass(player, item)
			thanks(player)
		end
	end)
end

return MonetizationService
