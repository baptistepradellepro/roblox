--[[
	CenterView : le milieu de la map côté joueur.
	  - la Roue de la Fortune : on la dessine, et on la fait tourner pour tout le monde
	    quand quelqu'un joue (le serveur a déjà choisi la case, on l'anime seulement)
	  - les boutons "Roue de la Fortune", "Boutique" et "Chaudron des monstres"
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Wheel = require(Shared:WaitForChild("Wheel"))

local Effects = require(script.Parent.Effects)
local Lang = require(script.Parent.Lang)
local Panels = require(script.Parent.Panels)
local UI = require(script.Parent.UI)

local CenterView = {}

local player = Players.LocalPlayer
local TWO_PI = 2 * math.pi

local wheelModel: Model? = nil
local anchor: BasePart? = nil
local angle = 0 -- angle actuel de la roue
local spin: { From: number, To: number, Start: number, Mine: boolean, Done: boolean }? = nil
local statusLabel: TextLabel? = nil

-- Petit texte sur chaque case
local function labelMaker(segment, holder: BasePart)
	local gui = UI.new("BillboardGui", {
		Name = "SegmentLabel",
		Size = UDim2.new(4.4, 0, 2.2, 0),
		LightInfluence = 0,
		MaxDistance = 120,
		AutoLocalize = Lang.autoLocalize,
		Adornee = holder,
		Parent = holder,
	})
	UI.label({
		Size = UDim2.fromScale(1, 1),
		Text = segment.Icon .. "\n" .. Lang.t("WheelShort_" .. segment.Id),
		MaxTextSize = 30,
		Parent = gui,
	})
end

local function place()
	if wheelModel and anchor then
		wheelModel:PivotTo(anchor.CFrame * CFrame.Angles(0, 0, angle))
	end
end

-- Angle final pour que la case "index" s'arrête sous la flèche (en haut)
local function finalAngle(index: number, offset: number): number
	return -Wheel.segmentAngle(index) + offset
end

local function onSpin()
	local wheelAnchor = anchor
	if not wheelAnchor then
		return
	end
	local index = wheelAnchor:GetAttribute("SpinSegment")
	local start = wheelAnchor:GetAttribute("SpinStart") or 0
	if type(index) ~= "number" then
		return
	end
	local target = finalAngle(index, wheelAnchor:GetAttribute("SpinOffset") or 0)
	local elapsed = workspace:GetServerTimeNow() - start
	if elapsed >= Wheel.SpinDuration then
		-- tour déjà fini (on vient d'arriver) : on se met directement sur la case
		angle = target
		place()
		return
	end
	-- 5 tours complets puis on ralentit jusqu'à la case
	local delta = (target - angle) % TWO_PI
	spin = {
		From = angle,
		To = angle + delta + 5 * TWO_PI,
		Start = start,
		Mine = wheelAnchor:GetAttribute("SpinnerId") == player.UserId,
		Done = false,
	}
	if statusLabel then
		statusLabel.Text = "🎡 " .. Lang.t("WheelSpinning", { player = wheelAnchor:GetAttribute("SpinnerName") or "?" })
	end
end

local function addPrompt(part: BasePart?, action: string, object: string, onTrigger: () -> ())
	if not part then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 3, 0)
	attachment.Parent = part
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.AutoLocalize = Lang.autoLocalize
	prompt.Parent = attachment
	prompt.Triggered:Connect(function()
		Effects.sound("Click")
		onTrigger()
	end)
end

local function bigSign(part: BasePart?, text: string, color: Color3, height: number)
	if not part then
		return nil
	end
	local gui = UI.new("BillboardGui", {
		Size = UDim2.fromOffset(340, 60),
		StudsOffsetWorldSpace = Vector3.new(0, height, 0),
		LightInfluence = 0,
		MaxDistance = 220,
		AutoLocalize = Lang.autoLocalize,
		Adornee = part,
		Parent = part,
	})
	return UI.label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
		MaxTextSize = 40,
		Parent = gui,
	})
end

function CenterView.start()
	local map = workspace:WaitForChild("Map")
	anchor = map:FindFirstChild("FortuneWheelAnchor", true) :: BasePart?
	if anchor then
		local model = Wheel.build(labelMaker)
		model.Parent = workspace
		wheelModel = model
		statusLabel = bigSign(anchor, "🎡 " .. Lang.t("WheelTitle"), UI.Colors.Gold, Wheel.Radius + 3)
		anchor:GetAttributeChangedSignal("SpinId"):Connect(onSpin)
		onSpin()
		place()
	end

	local stand = map:FindFirstChild("FortuneWheelStand")
	addPrompt(stand and stand:FindFirstChild("WheelSpot") :: BasePart?, Lang.t("WheelTitle"), "🎡", function()
		Panels.openShop("Wheel")
	end)
	local shop = map:FindFirstChild("ShopStand")
	local shopSpot = shop and shop:FindFirstChild("ShopSpot") :: BasePart?
	addPrompt(shopSpot, Lang.t("Shop"), "🛒", function()
		Panels.openShop("Weapons")
	end)
	bigSign(shop and shop:FindFirstChild("ShopCounter") :: BasePart?, "🛒 " .. string.upper(Lang.t("Shop")), UI.Colors.Orange, 11)
	local cauldron = shop and shop:FindFirstChild("Cauldron") :: BasePart?
	addPrompt(cauldron, Lang.t("MonstersTitle"), "👹", function()
		Panels.openShop("Monsters")
	end)

	local lastTick = 0
	RunService.RenderStepped:Connect(function()
		local current = spin
		if not current or current.Done then
			return
		end
		local p = math.clamp((workspace:GetServerTimeNow() - current.Start) / Wheel.SpinDuration, 0, 1)
		local eased = 1 - (1 - p) ^ 3
		local previous = angle
		angle = current.From + (current.To - current.From) * eased
		place()
		-- petit "tic" à chaque case qui passe
		local segmentSize = TWO_PI / #Wheel.Segments
		if math.floor(angle / segmentSize) ~= math.floor(previous / segmentSize) and os.clock() - lastTick > 0.05 then
			lastTick = os.clock()
			if current.Mine then
				Effects.sound("WheelTick")
			end
		end
		if p >= 1 then
			current.Done = true
			angle = current.To % TWO_PI
			if current.Mine then
				Effects.sound("WheelWin")
				if anchor then
					Effects.confetti(anchor.Position, 60)
				end
			end
			if statusLabel then
				statusLabel.Text = "🎡 " .. Lang.t("WheelTitle")
			end
		end
	end)
end

return CenterView
