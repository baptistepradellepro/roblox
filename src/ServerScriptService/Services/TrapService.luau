--[[
	TrapService : les pièges des bases (peau de banane, toile d'araignée, alarme).
	  - achetés avec des pièces sur leur emplacement, dans sa propre base
	  - gardés pour toujours (et après un rebirth, sauf si Config.RebirthKeepsTraps = false)
	  - le serveur regarde plusieurs fois par seconde qui marche dessus : seuls les
	    intrus sont touchés, jamais le propriétaire
	Les réglages sont dans Config.Traps, les textes et modèles dans Traps.luau.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Traps = require(Shared:WaitForChild("Traps"))

local AnnounceService = require(script.Parent.AnnounceService)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Guard = require(script.Parent.Guard)
local Hooks = require(script.Parent.Hooks)
local StealService = require(script.Parent.StealService)

local TrapService = {}

local TICK = 0.15
local BUY_RANGE = 12 -- distance max à l'emplacement pour acheter (le bouton s'active à 9)
local GROUND_HEIGHT = 6 -- les pièges sont au rez-de-chaussée

local bananaReadyAt: { [any]: number } = {} -- par base
local alarmReadyAt: { [any]: number } = {} -- par base
local webUntil: { [Player]: number } = {} -- pour ne pas re-ralentir en boucle

local function now(): number
	return os.clock()
end

local function trapModel(base, id: string): Model?
	local folder = base.Model:FindFirstChild("Traps")
	return folder and folder:FindFirstChild("Trap_" .. id) :: Model?
end

-- Montre ou cache un piège (owned = acheté, ready = prêt à resservir)
local function show(base, id: string, owned: boolean, ready: boolean)
	local model = trapModel(base, id)
	if not model then
		return
	end
	model:SetAttribute("Owned", owned)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name == "Spot" then
				p.Transparency = if owned then 1 else 0.35
			elseif p:GetAttribute("TrapLook") then
				p.Transparency = if owned and ready then p:GetAttribute("BaseTransparency") or 0 else 1
			end
		end
	end
end

local function ownedTraps(player: Player): { [string]: boolean }
	local data = DataService.get(player)
	return if data and type(data.Traps) == "table" then data.Traps else {}
end

-- Met la base d'un joueur à jour (à son arrivée, après un achat, un rebirth...)
function TrapService.refresh(player: Player)
	local base = BaseService.getBase(player)
	if not base then
		return
	end
	local owned = ownedTraps(player)
	for _, trap in Traps.List do
		show(base, trap.Id, owned[trap.Id] == true, (bananaReadyAt[base] or 0) <= now() or trap.Id ~= "Banana")
	end
end

-- Le joueur s'en va : sa base redevient vide
function TrapService.release(player: Player)
	local base = BaseService.getBase(player)
	if not base then
		return
	end
	for _, trap in Traps.List do
		show(base, trap.Id, false, true)
	end
	bananaReadyAt[base] = nil
	alarmReadyAt[base] = nil
end

---------------------------------------------------------------- Achat

local function onBuy(player: Player, trapId: any)
	if not Guard.rate(player, "BuyTrap", 0.5) then
		return
	end
	local trap = Traps.get(trapId)
	local data = DataService.get(player)
	local base = BaseService.getBase(player)
	if not trap or not data or not base then
		return
	end
	data.Traps = data.Traps or {}
	if data.Traps[trap.Id] then
		AnnounceService.notify(player, "TrapOwned", nil, "info")
		return
	end
	-- il faut être devant l'emplacement, dans sa base
	local root = Guard.root(player)
	local model = trapModel(base, trap.Id)
	local spot = model and model.PrimaryPart
	if not root or not spot or (root.Position - spot.Position).Magnitude > BUY_RANGE then
		return
	end
	local price = Config.Traps[trap.Id].Price
	if not EconomyService.trySpend(player, price) then
		AnnounceService.notify(player, "NotEnoughCoins", { coins = Format.short(price) }, "bad")
		return
	end
	data.Traps[trap.Id] = true
	TrapService.refresh(player)
	AnnounceService.notify(player, "TrapBought", { trap = trap.Id }, "good")
	AnnounceService.effect("Placed", { Position = spot.Position })
end

---------------------------------------------------------------- Déclenchement

local function slip(base, owner: Player, intruder: Player, root: BasePart)
	local settings = Config.Traps.Banana
	bananaReadyAt[base] = now() + settings.Cooldown
	show(base, "Banana", true, false)
	task.delay(settings.Cooldown, function()
		if BaseService.getBase(owner) == base and ownedTraps(owner).Banana then
			show(base, "Banana", true, true)
		end
	end)
	if StealService.isCarrying(intruder) then
		StealService.failCarry(intruder, "Trap", owner)
	end
	StealService.cancelHold(intruder)
	StealService.stun(intruder, settings.Stun)
	AnnounceService.effect("Slip", { Position = root.Position, TargetId = intruder.UserId })
	AnnounceService.effect("Knockback", { Direction = Vector3.new(0, 0, 0), Power = 0 }, intruder)
	AnnounceService.notify(intruder, "TrapSlipped", nil, "bad")
	AnnounceService.notify(owner, "TrapCaught", { player = intruder.DisplayName, trap = "Banana" }, "good")
	Hooks.fire("Trap", owner, 1)
end

local function web(owner: Player, intruder: Player, root: BasePart)
	local settings = Config.Traps.Web
	webUntil[intruder] = now() + settings.SlowTime
	StealService.cancelHold(intruder)
	StealService.slow(intruder, settings.Speed, settings.SlowTime)
	AnnounceService.effect("Web", { Position = root.Position })
	AnnounceService.notify(intruder, "TrapWebbed", nil, "bad")
	AnnounceService.notify(owner, "TrapCaught", { player = intruder.DisplayName, trap = "Web" }, "good")
	Hooks.fire("Trap", owner, 1)
end

local function alarm(base, owner: Player, intruder: Player)
	local settings = Config.Traps.Alarm
	alarmReadyAt[base] = now() + settings.Cooldown
	base.Model:SetAttribute("AlarmUntil", workspace:GetServerTimeNow() + settings.RingTime)
	AnnounceService.notify(owner, "AlarmOwner", { player = intruder.DisplayName }, "bad")
	AnnounceService.effect("Alarm", { Position = base.Origin.Position }, owner)
	AnnounceService.notify(intruder, "AlarmIntruder", nil, "info")
	AnnounceService.effect("AlarmNear", { Position = base.Origin.Position })
end

local function check()
	local t = now()
	for _, base in BaseService.allBases() do
		local owner = base.Owner
		if owner then
			local owned = ownedTraps(owner)
			if owned.Banana or owned.Web or owned.Alarm then
				for _, intruder in Players:GetPlayers() do
					if intruder ~= owner then
						local root = Guard.root(intruder)
						if root and BaseService.isInside(base, root.Position) then
							local localPos = base.Origin:PointToObjectSpace(root.Position)
							local onGround = localPos.Y < GROUND_HEIGHT
							if owned.Alarm and (alarmReadyAt[base] or 0) <= t then
								alarm(base, owner, intruder)
							end
							local banana = Traps.ById.Banana
							local dx, dz = localPos.X - banana.Position.X, localPos.Z - banana.Position.Z
							if owned.Banana and onGround and (bananaReadyAt[base] or 0) <= t and dx * dx + dz * dz <= banana.Radius ^ 2 then
								slip(base, owner, intruder, root)
							end
							local webTrap = Traps.ById.Web
							if
								owned.Web
								and onGround
								and (webUntil[intruder] or 0) <= t
								and math.abs(localPos.X - webTrap.Position.X) <= webTrap.HalfSize.X
								and math.abs(localPos.Z - webTrap.Position.Z) <= webTrap.HalfSize.Y
							then
								web(owner, intruder, root)
							end
						end
					end
				end
			end
		end
	end
end

-- Rebirth : on garde les pièges, ou pas (Config.RebirthKeepsTraps)
function TrapService.onRebirth(player: Player)
	if not Config.RebirthKeepsTraps then
		local data = DataService.get(player)
		if data then
			data.Traps = {}
		end
	end
	TrapService.refresh(player)
end

function TrapService.setup(player: Player)
	TrapService.refresh(player)
end

function TrapService.start()
	Remotes.get("BuyTrap").OnServerEvent:Connect(onBuy)
	Hooks.on("Rebirth", TrapService.onRebirth)
	Players.PlayerRemoving:Connect(function(player)
		webUntil[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			Guard.safely("Traps", check)
		end
	end)
end

return TrapService
