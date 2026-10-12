--[[
	CodeService : les codes promo (liste dans Config.Codes).
	Le joueur tape un code dans la Boutique, le serveur vérifie :
	  - que le code existe et n'a pas expiré
	  - que ce joueur ne l'a pas déjà utilisé (noté dans sa sauvegarde)
	Anti-triche : une tentative par seconde, et 20 essais ratés maximum par partie.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local GhostData = require(Shared:WaitForChild("GhostData"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local AnnounceService = require(script.Parent.AnnounceService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GhostService = require(script.Parent.GhostService)
local Guard = require(script.Parent.Guard)

local CodeService = {}

local MAX_FAILURES = 20
local failures: { [Player]: number } = {}

-- "  bouh 2026 " -> "BOUH2026"
function CodeService.normalize(code: string): string
	local cleaned = string.gsub(string.upper(code), "%s", "")
	return cleaned
end

local function redeem(player: Player, raw: any)
	if typeof(raw) ~= "string" or #raw == 0 or #raw > 30 then
		return
	end
	if not Guard.rate(player, "Code", 1) then
		return
	end
	if (failures[player] or 0) >= MAX_FAILURES then
		AnnounceService.notify(player, "CodeInvalid", nil, "bad")
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local key = CodeService.normalize(raw)
	local def = Config.Codes[key]
	if not def then
		failures[player] = (failures[player] or 0) + 1
		AnnounceService.notify(player, "CodeInvalid", nil, "bad")
		return
	end
	if def.Expires and def.Expires > 0 and os.time() > def.Expires then
		AnnounceService.notify(player, "CodeExpired", nil, "bad")
		return
	end
	if data.RedeemedCodes[key] then
		AnnounceService.notify(player, "CodeUsed", nil, "bad")
		return
	end
	data.RedeemedCodes[key] = true

	local coins = def.Coins or 0
	if def.Minutes then
		coins += math.max(def.Min or 0, math.floor(EconomyService.incomePerSecond(player) * 60 * def.Minutes))
	end
	local ghostId = nil
	if def.Ghost and GhostData.get(def.Ghost) then
		if GhostService.giveGhost(player, def.Ghost) then
			ghostId = def.Ghost
		else
			coins += GhostData.priceOf(def.Ghost) -- base pleine : on donne sa valeur
		end
	end
	if coins > 0 then
		EconomyService.add(player, coins, true)
	end

	if ghostId then
		AnnounceService.notify(player, "CodeOkGhost", { ghost = ghostId }, "good")
	else
		AnnounceService.notify(player, "CodeOk", { coins = Format.short(coins) }, "good")
	end
	AnnounceService.effect("Gift", {}, player)
end

function CodeService.start()
	Remotes.get("RedeemCode").OnServerEvent:Connect(redeem)
	Players.PlayerRemoving:Connect(function(player)
		failures[player] = nil
	end)
end

return CodeService
