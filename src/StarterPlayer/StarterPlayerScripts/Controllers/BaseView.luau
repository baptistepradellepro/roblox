--[[
	BaseView : affiche les bases de tout le monde.
	  - le panneau "TA BASE" / "Base de Léo" au-dessus de l'entrée
	  - les fantômes posés sur les socles (construits de notre côté, d'après les attributs)
	  - les boutons : "Voler" chez les autres, "Vendre" chez soi, "Verrouiller" sur le gros bouton
	  - la barrière du verrou : on peut la traverser dans SA base, pas chez les autres
	  - les pièces qui attendent au-dessus de chaque plaque verte
	  - l'ascenseur et l'achat de l'étage 2
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local GhostData = require(Shared:WaitForChild("GhostData"))
local GhostFactory = require(Shared:WaitForChild("GhostFactory"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Effects = require(script.Parent.Effects)
local Labels = require(script.Parent.Labels)
local Lang = require(script.Parent.Lang)
local UI = require(script.Parent.UI)

local BaseView = {}

local player = Players.LocalPlayer

type Slot = {
	Pedestal: BasePart,
	BaseModel: Model,
	BaseIndex: number,
	Slot: number,
	Model: Model?,
	Anchor: CFrame,
	Phase: number,
	Spin: number,
	Steal: ProximityPrompt,
	Sell: ProximityPrompt,
	Alert: BillboardGui?,
	StoredLabel: TextLabel?,
}

local slots: { Slot } = {}
local container: Folder

local function ownerOf(baseModel: Model): number
	return baseModel:GetAttribute("OwnerUserId") or 0
end

local function isMine(baseModel: Model): boolean
	return ownerOf(baseModel) == player.UserId
end

local function isLocked(baseModel: Model): boolean
	return workspace:GetServerTimeNow() < (baseModel:GetAttribute("LockedUntil") or 0)
end

---------------------------------------------------------------- Panneau d'entrée

local function setupSign(baseModel: Model)
	local sign = baseModel:WaitForChild("Sign") :: BasePart
	local surface = UI.new("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
		AutoLocalize = Lang.autoLocalize,
		Adornee = sign,
		Parent = sign,
	})
	local text = UI.label({
		Size = UDim2.fromScale(0.94, 0.86),
		Position = UDim2.fromScale(0.03, 0.07),
		MaxTextSize = 90,
		Parent = surface,
	})
	-- Cadenas + chrono au-dessus du panneau quand la base est verrouillée
	local lockTag = Labels.simple(sign, "", UI.Colors.Info, Vector3.new(0, 3.2, 0), 8)
	lockTag.MaxDistance = 140

	local function refresh()
		local owner = ownerOf(baseModel)
		if owner == 0 then
			text.Text = Lang.t("FreeBase")
			text.TextColor3 = UI.Colors.Gray
		elseif owner == player.UserId then
			text.Text = "⭐ " .. Lang.t("YourBase") .. " ⭐"
			text.TextColor3 = UI.Colors.Gold
		else
			text.Text = Lang.t("BaseOf", { name = baseModel:GetAttribute("OwnerName") or "?" })
			text.TextColor3 = baseModel:GetAttribute("Color") or UI.Colors.Text
		end
	end
	baseModel:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
	baseModel:GetAttributeChangedSignal("OwnerName"):Connect(refresh)
	refresh()

	local label = lockTag:FindFirstChild("Text") :: TextLabel
	RunService.Heartbeat:Connect(function()
		local remaining = (baseModel:GetAttribute("LockedUntil") or 0) - workspace:GetServerTimeNow()
		if remaining > 0 and ownerOf(baseModel) ~= 0 then
			local icon = if baseModel:GetAttribute("Shield") then "🛡️ " else "🔒 "
			label.Text = icon .. Format.time(remaining)
			lockTag.Enabled = true
		else
			lockTag.Enabled = false
		end
	end)
end

---------------------------------------------------------------- Barrière du verrou

local function setupBarrier(baseModel: Model)
	local function onChild(child: Instance)
		if child.Name == "Barrier" and isMine(baseModel) then
			-- chez moi : je peux traverser (seulement de mon côté, le serveur ne change rien)
			local parts = if child:IsA("BasePart") then { child } else child:GetDescendants()
			for _, p in parts do
				if p:IsA("BasePart") then
					p.CanCollide = false
					if p.Transparency < 1 then
						p.Transparency = 0.6
					end
				end
			end
		end
	end
	local function scan()
		for _, child in baseModel:GetChildren() do
			onChild(child)
		end
	end
	baseModel.ChildAdded:Connect(onChild)
	baseModel:GetAttributeChangedSignal("OwnerUserId"):Connect(scan)
	scan()
end

---------------------------------------------------------------- Bouton de verrouillage

local function setupLockButton(baseModel: Model)
	local button = baseModel:WaitForChild("LockButton") :: BasePart
	local attachment = Instance.new("Attachment")
	attachment.Position = button.CFrame:PointToObjectSpace(button.Position + Vector3.new(0, 2.5, 0))
	attachment.Parent = button
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Lang.t("Lock")
	prompt.ObjectText = "🔒"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.AutoLocalize = Lang.autoLocalize
	prompt.Parent = attachment
	prompt.Triggered:Connect(function()
		Effects.sound("Click")
		Remotes.get("RequestLock"):FireServer()
	end)
	local function refresh()
		prompt.Enabled = isMine(baseModel)
	end
	baseModel:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
	refresh()
	-- panneau au-dessus du poste de verrouillage, au fond de la base
	local tag = Labels.simple(button, "🚧 " .. Lang.t("LockStation"), UI.Colors.Bad, Vector3.new(0, 5, 0), 6)
	tag.MaxDistance = 50
end

---------------------------------------------------------------- Ascenseur et étage 2

local function setupElevator(baseModel: Model)
	local upPad = baseModel:WaitForChild("UpPad") :: BasePart
	local tag = Labels.simple(upPad, "", UI.Colors.Purple, Vector3.new(0, 4, 0), 8)
	tag.MaxDistance = 50
	local text = tag:FindFirstChild("Text") :: TextLabel
	local floor2 = baseModel:WaitForChild("Floor2")
	local downPad = floor2:WaitForChild("DownPad") :: BasePart
	local downTag = Labels.simple(downPad, "⬇️ " .. Lang.t("FloorDown"), UI.Colors.Purple, Vector3.new(0, 4, 0), 8)
	downTag.MaxDistance = 40

	-- Acheter l'étage (seulement pour le propriétaire, tant qu'il n'est pas acheté)
	local attachment = Instance.new("Attachment")
	attachment.Position = upPad.CFrame:PointToObjectSpace(upPad.Position + Vector3.new(0, 2.5, 0))
	attachment.Parent = upPad
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Lang.t("FloorBuy")
	prompt.ObjectText = "🪙 " .. Format.short(Config.FloorPrice)
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.AutoLocalize = Lang.autoLocalize
	prompt.Parent = attachment
	prompt.Triggered:Connect(function()
		Effects.sound("Click")
		Remotes.get("BuyFloor"):FireServer()
	end)

	local function refresh()
		local bought = baseModel:GetAttribute("Floors") == 2
		local owned = ownerOf(baseModel) ~= 0
		prompt.Enabled = isMine(baseModel) and not bought
		downTag.Enabled = bought
		tag.Enabled = owned
		if bought then
			text.Text = "⬆️ " .. Lang.t("FloorUp")
		else
			text.Text = "🔒 " .. Lang.t("FloorLocked", { coins = "🪙 " .. Format.short(Config.FloorPrice) })
		end
	end
	baseModel:GetAttributeChangedSignal("Floors"):Connect(refresh)
	baseModel:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
	refresh()
end

---------------------------------------------------------------- Socles

local function destroyGhost(slot: Slot)
	if slot.Model then
		slot.Model:Destroy()
		slot.Model = nil
	end
end

local function renderSlot(slot: Slot)
	local ped = slot.Pedestal
	local ghostId = ped:GetAttribute("GhostId") or ""
	local stolen = ped:GetAttribute("Stolen") == true
	local unlocked = ped:GetAttribute("Unlocked") == true
	local mine = isMine(slot.BaseModel)

	-- Fantôme sur le socle
	local currentId = slot.Model and slot.Model:GetAttribute("GhostId")
	if ghostId == "" or stolen then
		destroyGhost(slot)
	elseif currentId ~= ghostId then
		destroyGhost(slot)
		local model = GhostFactory.build(ghostId)
		local bottom = model:GetAttribute("Bottom") or 2
		slot.Anchor = (ped:GetAttribute("GhostCFrame") :: CFrame) * CFrame.new(0, bottom + 0.4, 0)
		slot.Spin = model:GetAttribute("Spin") or 1
		model:PivotTo(slot.Anchor)
		Labels.ghost(model.PrimaryPart :: BasePart, ghostId, "pedestal", model:GetAttribute("Top") or 2)
		model.Parent = container
		slot.Model = model
	end

	-- "!" rouge quand le fantôme est en train d'être volé
	if stolen and not slot.Alert then
		slot.Alert = Labels.simple(ped, "❗", UI.Colors.Bad, Vector3.new(0, 5, 0), 3)
	elseif not stolen and slot.Alert then
		slot.Alert:Destroy()
		slot.Alert = nil
	end

	-- Pièces qui attendent sur ce socle (au-dessus de la plaque verte)
	if slot.StoredLabel then
		local stored = ped:GetAttribute("Stored") or 0
		local label = slot.StoredLabel
		label.Text = "🪙 " .. Format.short(stored)
		label.TextColor3 = if mine then UI.Colors.Gold else UI.Colors.Text
		local storedGui = label.Parent :: BillboardGui
		storedGui.Enabled = stored >= 1 and unlocked
	end

	-- Texte du bouton "Vendre"
	local ghost = if ghostId ~= "" then GhostData.get(ghostId) else nil
	if ghost then
		slot.Sell.ActionText = Lang.t("SellFor", { coins = "🪙 " .. Format.short(math.floor(GhostData.priceOf(ghostId) * Config.SellRatio)) })
		slot.Sell.ObjectText = Lang.ghostName(ghostId)
		slot.Steal.ObjectText = Lang.ghostName(ghostId)
	end
end

-- Qui voit quel bouton ? (recalculé régulièrement, le serveur revérifie tout)
local function updatePrompts()
	local carrying = player:GetAttribute("CarryGhost") ~= nil
	for _, slot in slots do
		local ped = slot.Pedestal
		local hasGhost = (ped:GetAttribute("GhostId") or "") ~= "" and ped:GetAttribute("Stolen") ~= true
		local owner = ownerOf(slot.BaseModel)
		local mine = owner == player.UserId
		local stealOk = hasGhost and owner ~= 0 and not mine and not carrying and not isLocked(slot.BaseModel)
		if slot.Steal.Enabled ~= stealOk then
			slot.Steal.Enabled = stealOk
		end
		local sellOk = hasGhost and mine
		if slot.Sell.Enabled ~= sellOk then
			slot.Sell.Enabled = sellOk
		end
	end
end

local function makePrompt(parent: Instance, action: string, hold: number, range: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = range
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.AutoLocalize = Lang.autoLocalize
	prompt.Parent = parent
	return prompt
end

local function setupPedestal(baseModel: Model, ped: BasePart)
	local index = baseModel:GetAttribute("Index")
	local slotNumber = ped:GetAttribute("Slot")
	local top = ped:GetAttribute("GhostCFrame") :: CFrame

	local attachment = Instance.new("Attachment")
	attachment.Position = ped.CFrame:PointToObjectSpace(top.Position + Vector3.new(0, 2.5, 0))
	attachment.Parent = ped

	local steal = makePrompt(attachment, Lang.t("Steal"), Config.StealHoldDuration, Config.StealRange)
	local sell = makePrompt(attachment, Lang.t("Sell"), 1, 10)

	steal.PromptButtonHoldBegan:Connect(function()
		Remotes.get("StealBegin"):FireServer(index, slotNumber)
	end)
	steal.Triggered:Connect(function()
		Remotes.get("Steal"):FireServer(index, slotNumber)
	end)
	sell.Triggered:Connect(function()
		Remotes.get("SellGhost"):FireServer(slotNumber)
	end)

	local slot: Slot = {
		Pedestal = ped,
		BaseModel = baseModel,
		BaseIndex = index,
		Slot = slotNumber,
		Model = nil,
		Anchor = top,
		Phase = math.random() * math.pi * 2,
		Spin = 1,
		Steal = steal,
		Sell = sell,
		Alert = nil,
		StoredLabel = nil,
	}
	local pad = ped:FindFirstChild("CollectPad") :: BasePart?
	if pad then
		local storedTag = Labels.simple(pad, "", UI.Colors.Gold, Vector3.new(0, 2.2, 0), 5)
		storedTag.MaxDistance = 40
		storedTag.Enabled = false
		slot.StoredLabel = storedTag:FindFirstChild("Text") :: TextLabel
	end
	table.insert(slots, slot)

	local function refresh()
		renderSlot(slot)
	end
	ped:GetAttributeChangedSignal("GhostId"):Connect(refresh)
	ped:GetAttributeChangedSignal("Stolen"):Connect(refresh)
	ped:GetAttributeChangedSignal("Unlocked"):Connect(refresh)
	ped:GetAttributeChangedSignal("Stored"):Connect(refresh)
	baseModel:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
	refresh()
end

local function setupBase(baseModel: Model)
	task.spawn(setupSign, baseModel)
	task.spawn(setupLockButton, baseModel)
	task.spawn(setupElevator, baseModel)
	setupBarrier(baseModel)
	local pedestals = baseModel:WaitForChild("Pedestals")
	for _, ped in pedestals:GetChildren() do
		if ped:IsA("BasePart") then
			setupPedestal(baseModel, ped)
		end
	end
end

function BaseView.start()
	container = Instance.new("Folder")
	container.Name = "ClientBaseGhosts"
	container.Parent = workspace

	local map = workspace:WaitForChild("Map")
	local basesFolder = map:WaitForChild("Bases")
	for _, baseModel in basesFolder:GetChildren() do
		task.spawn(setupBase, baseModel)
	end

	-- Animation douce des fantômes proches (les lointains restent immobiles : économie de batterie)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		local t = os.clock()
		for _, slot in slots do
			local model = slot.Model
			if model and (slot.Anchor.Position - camPos).Magnitude < 75 then
				local bob = math.sin(t * 2 + slot.Phase) * 0.3
				local turn = if slot.Spin > 1 then t * slot.Spin else math.sin(t * 0.8 + slot.Phase) * 0.35
				model:PivotTo(slot.Anchor * CFrame.new(0, bob, 0) * CFrame.Angles(0, turn, 0))
			end
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.2 then
			accumulator = 0
			updatePrompts()
		end
	end)
end

return BaseView
