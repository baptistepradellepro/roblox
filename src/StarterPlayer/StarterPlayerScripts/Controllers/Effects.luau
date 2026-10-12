--[[
	Effects : les sons et les effets visuels (confettis, fumée, étoiles, secousses).
	Le serveur envoie "Effect" avec un type, et on joue l'effet ici.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Monsters = require(Shared:WaitForChild("Monsters"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Weapons = require(Shared:WaitForChild("Weapons"))

local AnimView = require(script.Parent.AnimView)

local Effects = {}

local player = Players.LocalPlayer

local CONFETTI_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 160)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 255)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(140, 255, 100)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 110, 255)),
})

local function playOnce(def, pitch: number)
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Volume = def.Volume or 0.5
	sound.PlaybackSpeed = pitch
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
end

-- Joue un son de la liste Sounds (ex. Effects.sound("Buy"))
function Effects.sound(name: string)
	local def = Sounds[name]
	if not def or def.Id == "" then
		return
	end
	if def.Jingle then
		task.spawn(function()
			for _, pitch in def.Jingle do
				playOnce(def, pitch)
				task.wait(0.09)
			end
		end)
	else
		playOnce(def, def.Pitch or 1)
	end
end

-- Musique en boucle (nuit, jour). Renvoie l'objet Sound pour pouvoir l'arrêter.
function Effects.music(name: string): Sound?
	local def = Sounds[name]
	if not def or def.Id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Volume = def.Volume or 0.3
	sound.Looped = true
	sound.Parent = SoundService
	sound:Play()
	return sound
end

local function emitAt(position: Vector3, setup: (ParticleEmitter) -> (), count: number, lifetime: number?)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	setup(emitter)
	emitter.Parent = holder
	emitter:Emit(count)
	Debris:AddItem(holder, lifetime or 3)
end

function Effects.confetti(position: Vector3, amount: number?)
	emitAt(position, function(e)
		e.Color = CONFETTI_COLORS
		e.Size = NumberSequence.new(0.35)
		e.Speed = NumberRange.new(18, 30)
		e.SpreadAngle = Vector2.new(60, 60)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, -35, 0)
		e.Drag = 1.5
		e.Lifetime = NumberRange.new(1.5, 2.2)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-300, 300)
		e.LightEmission = 0.4
	end, amount or 80)
end

function Effects.poof(position: Vector3, color: Color3?)
	emitAt(position, function(e)
		e.Color = ColorSequence.new(color or Color3.fromRGB(230, 220, 255))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new(0.2, 1)
		e.Speed = NumberRange.new(4, 9)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Lifetime = NumberRange.new(0.5, 0.8)
	end, 25, 2)
end

function Effects.stars(position: Vector3)
	emitAt(position, function(e)
		e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 80))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
		e.Speed = NumberRange.new(8, 12)
		e.SpreadAngle = Vector2.new(180, 30)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, -10, 0)
		e.Lifetime = NumberRange.new(0.6, 0.9)
		e.LightEmission = 1
	end, 18, 2)
end

function Effects.coins(position: Vector3)
	emitAt(position, function(e)
		e.Color = ColorSequence.new(Color3.fromRGB(255, 210, 50))
		e.Size = NumberSequence.new(0.5)
		e.Speed = NumberRange.new(10, 16)
		e.SpreadAngle = Vector2.new(40, 40)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, -40, 0)
		e.Lifetime = NumberRange.new(0.8, 1.1)
		e.LightEmission = 0.6
	end, 20, 2)
end

-- Un "+1.2K" doré qui monte et disparaît (récolte des pièces)
function Effects.floatingText(position: Vector3, text: string)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = holder
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 210, 60)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	TweenService:Create(gui, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { StudsOffsetWorldSpace = Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(holder, 1.2)
end

-- Petite secousse de caméra
function Effects.shake(strength: number?, duration: number?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local s = strength or 0.6
	local steps = math.floor((duration or 0.4) / 0.05)
	task.spawn(function()
		for _ = 1, steps do
			humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
			task.wait(0.05)
		end
		TweenService:Create(humanoid, TweenInfo.new(0.1), { CameraOffset = Vector3.zero }):Play()
	end)
end

local function isNear(position: Vector3?, range: number): boolean
	if not position then
		return false
	end
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= range
end

-- Ce que fait chaque type d'effet envoyé par le serveur
local handlers: { [string]: (data: { [string]: any }) -> () } = {
	Placed = function(data)
		if data.Position then
			Effects.poof(data.Position + Vector3.new(0, 3, 0))
		end
	end,
	Bought = function()
		Effects.sound("Buy")
	end,
	Sold = function(data)
		if data.Position then
			Effects.coins(data.Position + Vector3.new(0, 2, 0))
			if isNear(data.Position, 40) then
				Effects.sound("Sell")
			end
		end
	end,
	Lock = function(data)
		if isNear(data.Position, 80) then
			Effects.sound("Lock")
		end
	end,
	StealStart = function()
		Effects.sound("StealStart")
	end,
	StealAlert = function()
		Effects.sound("StealAlert")
		Effects.shake(0.5, 0.5)
	end,
	StealSuccess = function(data)
		if data.Position then
			Effects.confetti(data.Position + Vector3.new(0, 3, 0), 120)
		end
		if data.ThiefId == player.UserId then
			Effects.sound("StealSuccess")
			Effects.shake(0.4, 0.3)
		elseif data.OwnerId == player.UserId then
			Effects.sound("StealFail")
		else
			Effects.sound("Buy")
		end
	end,
	StealFail = function()
		Effects.sound("StealFail")
	end,
	Recovered = function(data)
		if data.Position then
			Effects.poof(data.Position + Vector3.new(0, 3, 0), Color3.fromRGB(150, 255, 170))
		end
	end,
	Bonk = function(data)
		if data.Position then
			Effects.stars(data.Position + Vector3.new(0, 3, 0))
			if isNear(data.Position, 90) then
				local weapon = Weapons.get(data.Weapon)
				Effects.sound(if weapon then weapon.Sound else "Bonk")
			end
		end
		AnimView.hitByUserId(data.TargetId)
	end,
	Swing = function(data)
		local mine = data.PlayerId == player.UserId
		-- mon propre coup est déjà animé et a déjà fait son bruit (tout de suite, sans attendre)
		if not mine and data.Position and isNear(data.Position, 50) then
			Effects.sound("Swing")
		end
		local target = if typeof(data.Target) == "Vector3" then data.Target else nil
		AnimView.swingByUserId(data.PlayerId, data.Weapon, target, not mine, true)
	end,
	-- J'ai pris un coup : je recule (c'est mon écran qui bouge mon personnage)
	Knockback = function(data)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and typeof(data.Direction) == "Vector3" then
			local power = math.clamp(tonumber(data.Power) or 40, 0, 120)
			root.AssemblyLinearVelocity = data.Direction * power + Vector3.new(0, 28, 0)
			Effects.shake(0.8, 0.3)
		end
	end,
	MonsterSummon = function()
		Effects.sound("MonsterSummon")
		Effects.shake(0.6, 0.5)
	end,
	Gift = function()
		Effects.sound("Gift")
	end,
	MonsterCatch = function(data)
		if data.Position then
			local monster = Monsters.get(data.Monster)
			local color = if monster then Color3.fromRGB(monster.Color[1], monster.Color[2], monster.Color[3]) else Color3.fromRGB(255, 140, 30)
			Effects.poof(data.Position, color)
		end
		if data.PlayerId == player.UserId then
			Effects.sound("MonsterCatch")
			Effects.shake(1.2, 0.6)
		end
	end,
	NightStart = function(data)
		Effects.sound("NightStart")
		if data.Theme == "Super" then
			Effects.shake(1.6, 1.2)
		else
			Effects.shake(0.8, 0.8)
		end
	end,
	Collect = function(data)
		if data.Position then
			Effects.coins(data.Position)
			Effects.floatingText(data.Position, "+" .. Format.short(data.Amount or 0))
		end
		Effects.sound("Sell")
	end,
	Elevator = function()
		Effects.sound("StealStart")
	end,
	CoinPickup = function(data)
		if data.Position then
			Effects.coins(data.Position)
		end
		Effects.sound("Sell")
	end,
	NightEnd = function()
		Effects.sound("NightEnd")
	end,
	Rebirth = function(data)
		if data.Position then
			Effects.confetti(data.Position + Vector3.new(0, 4, 0), 160)
		end
		if data.PlayerId == player.UserId then
			Effects.sound("Rebirth")
		end
	end,
}

function Effects.start()
	Remotes.get("Effect").OnClientEvent:Connect(function(kind: string, data: { [string]: any })
		local handler = handlers[kind]
		if handler then
			handler(data or {})
		end
	end)
end

return Effects
