--[[
	RebirthService : recommencer à zéro contre un bonus permanent.
	  - coût : 5M, puis x3 à chaque rebirth (15M, 45M...)
	  - on perd les pièces et les fantômes (on garde le fantôme de départ et l'étage 2)
	  - on gagne +50 % de revenus pour toujours et une aura qui se voit
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local AnnounceService = require(script.Parent.AnnounceService)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GhostService = require(script.Parent.GhostService)
local Guard = require(script.Parent.Guard)
local StealService = require(script.Parent.StealService)

local RebirthService = {}

-- Couleurs de l'aura selon le nombre de rebirths
local AURA_COLORS = {
	Color3.fromRGB(120, 255, 200),
	Color3.fromRGB(90, 170, 255),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 200, 50),
	Color3.fromRGB(255, 70, 140),
}

function RebirthService.cost(rebirths: number): number
	return math.floor(Config.RebirthBaseCost * Config.RebirthCostGrowth ^ rebirths)
end

local function applyAura(player: Player)
	local data = DataService.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not root then
		return
	end
	local old = root:FindFirstChild("RebirthAura")
	if old then
		old:Destroy()
	end
	if data.Rebirths <= 0 then
		return
	end
	local color = AURA_COLORS[math.min(data.Rebirths, #AURA_COLORS)]
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "RebirthAura"
	aura.Color = ColorSequence.new(color)
	aura.LightEmission = 1
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	aura.Transparency = NumberSequence.new(0.3, 1)
	aura.Speed = NumberRange.new(1, 2)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Lifetime = NumberRange.new(0.8, 1.2)
	aura.Rate = 3 + math.min(data.Rebirths, 10) * 2
	aura.Parent = root
end

local function onRebirth(player: Player)
	if not Guard.rate(player, "Rebirth", 2) then
		return
	end
	local data = DataService.get(player)
	local base = BaseService.getBase(player)
	if not data or not base then
		return
	end
	if StealService.isCarrying(player) or StealService.isBeingStolenFrom(player) then
		AnnounceService.notify(player, "RebirthBusy", nil, "bad")
		return
	end
	local price = RebirthService.cost(data.Rebirths)
	if data.Coins < price then
		AnnounceService.notify(player, "RebirthNotEnough", { coins = Format.short(price) }, "bad")
		return
	end

	-- On remet tout à zéro...
	data.Coins = Config.StartCoins
	data.Rebirths += 1
	if not Config.RebirthKeepsFloors then
		data.Floors = 1
	end
	BaseService.clearAllGhosts(player)
	-- ...mais on garde un fantôme pour repartir tout de suite
	GhostService.giveGhost(player, Config.StarterGhost)
	BaseService.refreshSlots(player)
	EconomyService.refresh(player)
	applyAura(player)

	local mult = EconomyService.rebirthMultiplier(data.Rebirths)
	AnnounceService.notify(player, "RebirthDone", { mult = mult }, "good")
	AnnounceService.announce("AnnRebirth", { player = player.DisplayName, count = data.Rebirths }, "rebirth")
	AnnounceService.effect("Rebirth", { Position = base.Origin.Position, PlayerId = player.UserId })
	task.spawn(DataService.save, player, false)
end

function RebirthService.setup(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		applyAura(player)
	end)
end

function RebirthService.start()
	Remotes.get("Rebirth").OnServerEvent:Connect(onRebirth)
end

return RebirthService
