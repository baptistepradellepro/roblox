--[[
	WheelService : la Roue de la Fortune au milieu de la map.
	  - les tours s'achètent avec des Robux (voir MonetizationService) et sont sauvegardés
	  - le joueur demande à tourner : le SERVEUR tire la case gagnante (anti-triche)
	  - tout le serveur voit la roue tourner ; le gain est donné quand elle s'arrête
	  - une seule personne à la fois : la roue est partagée
	Les cases et leurs chances sont dans Wheel.luau.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local GhostData = require(Shared:WaitForChild("GhostData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Wheel = require(Shared:WaitForChild("Wheel"))

local AnnounceService = require(script.Parent.AnnounceService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GhostService = require(script.Parent.GhostService)
local Guard = require(script.Parent.Guard)

local WheelService = {}

local anchor: BasePart? = nil
local busyUntil = 0
local rng = Random.new()
local pending: { [Player]: number } = {} -- case gagnée, pas encore donnée (la roue tourne)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function syncSpins(player: Player)
	local data = DataService.get(player)
	if data then
		player:SetAttribute("Spins", data.Spins or 0)
	end
end

function WheelService.addSpins(player: Player, count: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.Spins = (data.Spins or 0) + count
	syncSpins(player)
	AnnounceService.notify(player, "SpinsAdded", { count = count }, "good")
end

-- Donne le gain d'une case
local function grant(player: Player, index: number)
	local segment = Wheel.Segments[index]
	local data = DataService.get(player)
	if not segment or not data then
		return
	end
	if segment.Kind == "Coins" then
		local coins = Wheel.coins(segment, EconomyService.incomePerSecond(player))
		EconomyService.add(player, coins)
		AnnounceService.notify(player, "WheelWinCoins", { coins = Format.short(coins) }, "good")
	elseif segment.Kind == "Boost" then
		local t = os.time()
		data.BoostUntil = math.max(data.BoostUntil or 0, t) + segment.Seconds
		EconomyService.refresh(player)
		AnnounceService.notify(player, "WheelWinBoost", { mult = Config.WheelBoostMult, time = Format.time(segment.Seconds) }, "good")
		-- remet le revenu normal à la fin du boost
		task.delay(data.BoostUntil - t + 1, function()
			if player.Parent then
				EconomyService.refresh(player)
			end
		end)
	elseif segment.Kind == "Ghost" then
		local ghost = GhostData.pick(segment.Rarity, rng:NextNumber())
		local key = GhostData.key(ghost.Id, segment.Mutation)
		if GhostService.giveGhost(player, key) then
			AnnounceService.notify(player, "WheelWinGhost", { ghost = key }, "good")
		else
			-- base pleine : on paie le prix du fantôme en pièces
			local coins = GhostData.priceOf(key)
			EconomyService.add(player, coins)
			AnnounceService.notify(player, "WheelBaseFull", { ghost = key, coins = Format.short(coins) }, "good")
		end
		if segment.Rarity == "Legendary" or segment.Rarity == "Mythic" then
			AnnounceService.announce("AnnWheel", { player = player.DisplayName, ghost = key }, "rebirth")
		end
	end
	AnnounceService.effect("Gift", {}, player)
end

local function onSpin(player: Player)
	if not Guard.rate(player, "SpinWheel", 0.5) then
		return
	end
	local data = DataService.get(player)
	if not data or not anchor then
		return
	end
	if (data.Spins or 0) <= 0 then
		AnnounceService.notify(player, "WheelNoSpins", nil, "bad")
		return
	end
	if pending[player] then
		return
	end
	local t = os.clock()
	if t < busyUntil then
		AnnounceService.notify(player, "WheelBusy", { time = Format.time(busyUntil - t) }, "info")
		return
	end
	data.Spins -= 1
	syncSpins(player)
	local index = Wheel.pick(rng:NextNumber())
	pending[player] = index
	busyUntil = t + Wheel.SpinDuration + 0.5

	local wheel = anchor :: BasePart
	wheel:SetAttribute("SpinSegment", index)
	wheel:SetAttribute("SpinStart", now())
	wheel:SetAttribute("SpinOffset", rng:NextNumber(-0.3, 0.3))
	wheel:SetAttribute("SpinnerName", player.DisplayName)
	wheel:SetAttribute("SpinnerId", player.UserId)
	wheel:SetAttribute("SpinId", (wheel:GetAttribute("SpinId") or 0) + 1)

	task.delay(Wheel.SpinDuration, function()
		if pending[player] == index then
			pending[player] = nil
			if player.Parent then
				grant(player, index)
			end
		end
	end)
end

-- Le joueur part pendant que la roue tourne : on lui donne son gain avant la sauvegarde
function WheelService.onPlayerRemoving(player: Player)
	local index = pending[player]
	pending[player] = nil
	if index then
		grant(player, index)
	end
end

function WheelService.setup(player: Player)
	syncSpins(player)
end

function WheelService.init(map: Instance)
	anchor = map:FindFirstChild("FortuneWheelAnchor", true) :: BasePart?
	if not anchor then
		warn("[WheelService] Roue introuvable dans la map")
	end
end

function WheelService.start()
	Remotes.get("SpinWheel").OnServerEvent:Connect(onSpin)
end

return WheelService
