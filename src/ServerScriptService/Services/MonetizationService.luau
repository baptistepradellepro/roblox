--[[
	MonetizationService : Game Passes et Developer Product (optionnels).
	  - Game Pass "x2 Pièces" : double les revenus
	  - Game Pass "Verrou+" : verrou plus long (Config.LockDurationPass au lieu de Config.LockDuration)
	  - Developer Product "Pack de pièces" : 10 min de revenus (minimum 5 000)
	Rien de tout ça n'aide à voler : pas de pay-to-win sur le vol.

	Tant que les IDs valent 0 dans Config, tout est désactivé et le jeu marche normalement.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local AnnounceService = require(script.Parent.AnnounceService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local MonetizationService = {}

-- Attribut posé sur le joueur pour chaque Game Pass
local PASS_ATTRIBUTES = {
	DoubleCoins = "DoubleCoins",
	LongLock = "LongLock",
}

local function passIdToAttribute(passId: number): string?
	for key, id in Config.GamePasses do
		if id ~= 0 and id == passId then
			return PASS_ATTRIBUTES[key]
		end
	end
	return nil
end

-- Vérifie les Game Passes du joueur à son arrivée
function MonetizationService.setup(player: Player)
	for key, passId in Config.GamePasses do
		if passId ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			if ok and owns then
				player:SetAttribute(PASS_ATTRIBUTES[key], true)
			end
		end
	end
end

function MonetizationService.coinPackAmount(player: Player): number
	local perMinute = EconomyService.incomePerSecond(player) * 60
	return math.max(Config.CoinPackMin, math.floor(perMinute * Config.CoinPackMinutes))
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
	if receipt.ProductId == Config.Products.CoinPack and Config.Products.CoinPack ~= 0 then
		EconomyService.add(player, MonetizationService.coinPackAmount(player))
	else
		warn("[Monetization] Produit inconnu : " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(data.Receipts, receipt.PurchaseId)
	while #data.Receipts > 50 do
		table.remove(data.Receipts, 1)
	end
	AnnounceService.notify(player, "ShopThanks", nil, "good")
	AnnounceService.effect("Gift", {}, player)
	-- on sauvegarde tout de suite ; si ça échoue, Roblox réessaiera plus tard
	if DataService.save(player, false) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local attribute = passIdToAttribute(passId)
		if attribute then
			player:SetAttribute(attribute, true)
			EconomyService.refresh(player)
			AnnounceService.notify(player, "ShopThanks", nil, "good")
			AnnounceService.effect("Gift", {}, player)
		end
	end)
end

return MonetizationService
