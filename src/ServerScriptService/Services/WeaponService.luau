--[[
	WeaponService : les armes pour chasser les voleurs.
	  - chaque joueur reçoit la Batte à chaque apparition, plus les armes qu'il a achetées
	  - le joueur frappe (clic, touche Q ou bouton à l'écran) : le serveur vérifie tout
	    (arme possédée, temps de recharge, distance) et applique l'effet
	  - un voleur touché lâche le fantôme (il rentre chez lui), recule et est étourdi
	  - un intrus touché dans TA base est renvoyé dehors
	  - on ne peut pas frapper en portant un fantôme volé (les armes servent à défendre)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Weapons = require(Shared:WaitForChild("Weapons"))

local AnnounceService = require(script.Parent.AnnounceService)
local BaseService = require(script.Parent.BaseService)
local Guard = require(script.Parent.Guard)
local Hooks = require(script.Parent.Hooks)
local MapBuilder = require(script.Parent.MapBuilder)
local StealService = require(script.Parent.StealService)

local WeaponService = {}

local readyAt: { [Player]: number } = {}

-- Le joueur a-t-il cette arme ? (la Batte est offerte)
function WeaponService.owns(player: Player, weapon): boolean
	return weapon.Free == true or player:GetAttribute("Weapon_" .. weapon.Id) == true
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Met les armes du joueur dans son sac (sans doublon)
function WeaponService.giveTools(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	local character = player.Character
	for _, weapon in Weapons.List do
		if WeaponService.owns(player, weapon) then
			local has = false
			for _, container in { backpack, character } do
				if container then
					for _, child in container:GetChildren() do
						if child:IsA("Tool") and child:GetAttribute("WeaponId") == weapon.Id then
							has = true
						end
					end
				end
			end
			if not has then
				Weapons.buildTool(weapon.Id).Parent = backpack
			end
		end
	end
end

-- Pousse un joueur loin de "from" : le serveur l'étourdit, son écran le fait reculer
local function knock(target: Player, from: Vector3, weapon)
	local root = Guard.root(target)
	if not root then
		return
	end
	local away = flat(root.Position - from)
	local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
	AnnounceService.effect("Knockback", { Direction = direction, Power = weapon.Knock }, target)
end

-- Renvoie un intrus devant l'entrée de la base
local function pushOut(base, target: Player)
	local character = target.Character
	if character then
		character:PivotTo(base.Origin * CFrame.new(math.random(-4, 4), 3, -MapBuilder.BASE_DEPTH / 2 - 6))
	end
end

local function onSwing(player: Player, weaponId: any)
	if not Guard.rate(player, "Swing", 0.15) then
		return
	end
	local weapon = Weapons.get(weaponId) or Weapons.ById.Batte
	if not WeaponService.owns(player, weapon) then
		return
	end
	local t = os.clock()
	if (readyAt[player] or 0) > t or StealService.isCarrying(player) or StealService.isStunned(player) then
		return
	end
	local root = Guard.root(player)
	if not root then
		return
	end
	readyAt[player] = t + weapon.Cooldown
	-- les cibles possibles : voleurs à portée, intrus dans ma base
	local myBase = BaseService.getBase(player)
	local targets = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherRoot = Guard.root(other)
			if otherRoot then
				local dist = (otherRoot.Position - root.Position).Magnitude
				local isThief = StealService.isCarrying(other)
				local isIntruder = myBase ~= nil and BaseService.isInside(myBase, otherRoot.Position)
				if dist <= weapon.Range + 1 and (isThief or isIntruder) then
					table.insert(targets, { Player = other, Dist = dist, Thief = isThief, Root = otherRoot })
				end
			end
		end
	end
	table.sort(targets, function(a, b)
		return a.Dist < b.Dist
	end)
	if not weapon.Sweep and #targets > 1 then
		targets = { targets[1] }
	end
	-- tout le monde voit le geste (et le rayon de l'aspirateur vers la cible)
	AnnounceService.effect("Swing", {
		PlayerId = player.UserId,
		Position = root.Position,
		Weapon = weapon.Id,
		Target = if targets[1] then targets[1].Root.Position else nil,
	})
	for _, target in targets do
		local other = target.Player
		AnnounceService.effect("Bonk", { Position = target.Root.Position, Weapon = weapon.Id, TargetId = other.UserId })
		if target.Thief then
			StealService.failCarry(other, "Bonk", player)
			Hooks.fire("Bonk", player, 1)
		else
			StealService.cancelHold(other)
			if myBase then
				pushOut(myBase, other)
			end
			AnnounceService.notify(other, "PushedOut", { player = player.DisplayName }, "bad")
		end
		StealService.stun(other, weapon.Stun)
		knock(other, root.Position, weapon)
	end
end

-- Un Game Pass d'arme vient d'être acheté (ou est déjà possédé à l'arrivée)
function WeaponService.onPassOwned(player: Player)
	WeaponService.giveTools(player)
end

-- Quand on porte un fantôme volé, on range ses armes (on ne peut pas frapper)
local function stowWhenCarrying(player: Player)
	if player:GetAttribute("CarryGhost") then
		local humanoid = Guard.humanoid(player)
		if humanoid then
			humanoid:UnequipTools()
		end
	end
end

function WeaponService.setup(player: Player)
	player:GetAttributeChangedSignal("CarryGhost"):Connect(function()
		stowWhenCarrying(player)
	end)
	player.CharacterAdded:Connect(function()
		-- le sac est recréé à chaque apparition
		task.defer(WeaponService.giveTools, player)
	end)
	if player.Character then
		WeaponService.giveTools(player)
	end
end

function WeaponService.start()
	Remotes.get("Bonk").OnServerEvent:Connect(onSwing)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return WeaponService
