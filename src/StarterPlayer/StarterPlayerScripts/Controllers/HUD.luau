--[[
	HUD : l'interface principale, pensée d'abord pour le mobile.
	  - en haut : tes pièces et ton revenu par seconde
	  - à droite : gros boutons Verrou et Marteau Pouet
	  - au centre : petits messages (notifications) et chrono quand tu portes un fantôme
	Le HUD ne fait qu'AFFICHER et DEMANDER : toutes les décisions sont prises par le serveur.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Effects = require(script.Parent.Effects)
local Lang = require(script.Parent.Lang)
local UI = require(script.Parent.UI)

local HUD = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local toastList: Frame
local toastCount = 0

-- Colonnes de boutons (d'autres modules y ajoutent les leurs)
HUD.rightColumn = nil :: Frame?
HUD.leftColumn = nil :: Frame?
HUD.infoRow = nil :: Frame?
HUD.gui = nil :: ScreenGui?

local function myBase(): Model?
	local index = player:GetAttribute("BaseIndex")
	local map = workspace:FindFirstChild("Map")
	local bases = map and map:FindFirstChild("Bases")
	return bases and index and bases:FindFirstChild("Base_" .. index) :: Model?
end
HUD.myBase = myBase

---------------------------------------------------------------- Notifications

function HUD.toast(text: string, kind: string?)
	if not toastList then
		return
	end
	local color = if kind == "good" then UI.Colors.Good elseif kind == "bad" then UI.Colors.Bad else UI.Colors.Info
	toastCount += 1
	local frame = UI.new("Frame", {
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.08,
		LayoutOrder = toastCount,
		Parent = toastList,
	}, { UI.corner(12), UI.stroke(color, 3) })
	UI.label({
		Size = UDim2.new(1, -18, 1, -8),
		Position = UDim2.fromOffset(9, 4),
		Text = text,
		MaxTextSize = 26,
		Parent = frame,
	})
	UI.pop(frame)
	if kind == "bad" then
		Effects.sound("Error")
	end
	-- 3 messages maximum à l'écran
	local toasts = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - 3 do
		toasts[i]:Destroy()
	end
	task.delay(3.2, function()
		if frame.Parent then
			TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			for _, d in frame:GetDescendants() do
				if d:IsA("TextLabel") then
					TweenService:Create(d, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				elseif d:IsA("UIStroke") then
					TweenService:Create(d, TweenInfo.new(0.3), { Transparency = 1 }):Play()
				end
			end
			task.wait(0.35)
			frame:Destroy()
		end
	end)
end

---------------------------------------------------------------- Construction

local coinLabel: TextLabel
local incomeLabel: TextLabel
local friendLabel: TextLabel
local lockButton: TextButton
local lockIcon: TextLabel
local lockText: TextLabel
local bonkButton: TextButton
local bonkText: TextLabel
local carryBanner: TextLabel
local bonkCooldownUntil = 0
local shownCoins = 0

-- Petite pastille d'info (ex. minuteur de nuit) dans la ligne sous les pièces
function HUD.pill(color: Color3, order: number): Frame
	local pill = UI.new("Frame", {
		Name = "Pill",
		Size = UDim2.fromOffset(190, 34),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		LayoutOrder = order,
		Visible = false,
		Parent = HUD.infoRow,
	}, { UI.corner(17), UI.stroke(color, 2) })
	UI.label({
		Name = "Text",
		Size = UDim2.new(1, -12, 1, -6),
		Position = UDim2.fromOffset(6, 3),
		TextColor3 = color,
		MaxTextSize = 22,
		Parent = pill,
	})
	return pill
end

local function buildTopBar()
	local panel = UI.new("Frame", {
		Name = "Coins",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(300, 82),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.05,
		Parent = gui,
	}, { UI.corner(20), UI.stroke(UI.Colors.Gold, 3) })
	UI.label({
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.fromOffset(10, 4),
		Text = "🪙",
		MaxTextSize = 50,
		Parent = panel,
	})
	coinLabel = UI.label({
		Size = UDim2.new(1, -82, 0, 50),
		Position = UDim2.fromOffset(72, 2),
		Text = "0",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Gold,
		MaxTextSize = 46,
		Parent = panel,
	})
	incomeLabel = UI.label({
		Size = UDim2.new(1, -82, 0, 26),
		Position = UDim2.fromOffset(72, 52),
		Text = "+0/s",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Good,
		MaxTextSize = 24,
		Parent = panel,
	})
	-- Ligne d'infos sous les pièces (minuteur de nuit, bonus amis)
	HUD.infoRow = UI.new("Frame", {
		Name = "InfoRow",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 94),
		Size = UDim2.fromOffset(420, 34),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	local friendPill = HUD.pill(UI.Colors.Info, 2)
	friendLabel = friendPill:FindFirstChild("Text") :: TextLabel

	toastList = UI.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 136),
		Size = UDim2.fromOffset(540, 160),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})

	carryBanner = UI.label({
		Name = "CarryBanner",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.82, 0),
		Size = UDim2.fromOffset(620, 54),
		Text = "",
		TextColor3 = UI.Colors.Gold,
		MaxTextSize = 44,
		Visible = false,
		Parent = gui,
	})
end

local function buildColumns()
	HUD.rightColumn = UI.new("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.42, 0),
		Size = UDim2.fromOffset(112, 360),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
	HUD.leftColumn = UI.new("Frame", {
		Name = "Left",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.45, 0),
		Size = UDim2.fromOffset(100, 380),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})

	lockButton, lockIcon, lockText = UI.bigButton({
		Name = "Lock",
		Icon = "🔒",
		Text = Lang.t("LockReady"),
		Color = UI.Colors.Good,
		LayoutOrder = 1,
		Parent = HUD.rightColumn,
	})
	lockButton.Activated:Connect(function()
		Effects.sound("Click")
		Remotes.get("RequestLock"):FireServer()
	end)

	local bonkCaption = Lang.t("Bonk") .. (if UI.isMobile() then "" else " (Q)")
	local createdBonk, _, createdBonkText = UI.bigButton({
		Name = "Bonk",
		Icon = "🔨",
		Text = bonkCaption,
		Color = UI.Colors.Bad,
		Size = 112,
		LayoutOrder = 2,
		Parent = HUD.rightColumn,
	})
	bonkButton = createdBonk
	bonkText = createdBonkText
	bonkButton.Visible = false
	bonkText:SetAttribute("Default", bonkCaption)
end

---------------------------------------------------------------- Mise à jour

local function updateCoins()
	local coins = player:GetAttribute("Coins") or 0
	local income = player:GetAttribute("Income") or 0
	if coins > shownCoins + math.max(income * 3, 50) then
		UI.pop(coinLabel)
	end
	shownCoins = coins
	coinLabel.Text = Format.short(coins)
	incomeLabel.Text = Lang.t("Income", { coins = Format.short(income) })
	local friends = player:GetAttribute("FriendBonus") or 0
	local pill = friendLabel.Parent :: Frame
	pill.Visible = friends > 0
	friendLabel.Text = "👥 " .. Lang.t("FriendsBonus", { percent = math.floor(friends * 100 + 0.5) })
end

local function updateLock(now: number)
	local base = myBase()
	if not base then
		lockButton.Visible = false
		return
	end
	lockButton.Visible = true
	local lockedUntil = base:GetAttribute("LockedUntil") or 0
	local readyAt = base:GetAttribute("LockReadyAt") or 0
	if now < lockedUntil then
		lockButton.BackgroundColor3 = UI.Colors.Info
		lockIcon.Text = if base:GetAttribute("Shield") then "🛡️" else "🔒"
		lockText.Text = Lang.t("LockedFor", { time = Format.time(lockedUntil - now) })
	elseif now < readyAt then
		lockButton.BackgroundColor3 = UI.Colors.Gray
		lockIcon.Text = "⏳"
		lockText.Text = Format.time(readyAt - now)
	else
		lockButton.BackgroundColor3 = UI.Colors.Good
		lockIcon.Text = "🔒"
		lockText.Text = Lang.t("LockReady")
	end
end

-- Y a-t-il un voleur (autre que moi) à portée de Marteau Pouet ?
local function thiefInRange(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("CarryGhost") then
			local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if otherRoot and (otherRoot.Position - root.Position).Magnitude <= Config.BonkRange + 2 then
				return true
			end
		end
	end
	return false
end

local function tryBonk()
	if os.clock() < bonkCooldownUntil or not thiefInRange() then
		return
	end
	bonkCooldownUntil = os.clock() + Config.BonkCooldown
	Remotes.get("Bonk"):FireServer()
end

local function updateBonk()
	local inRange = thiefInRange()
	local wasVisible = bonkButton.Visible
	bonkButton.Visible = inRange
	if inRange and not wasVisible then
		UI.pop(bonkButton)
	end
	local cooldown = bonkCooldownUntil - os.clock()
	if cooldown > 0 then
		bonkButton.BackgroundColor3 = UI.Colors.Gray
		bonkText.Text = string.format("%.1f", cooldown)
	else
		bonkButton.BackgroundColor3 = UI.Colors.Bad
		bonkText.Text = bonkText:GetAttribute("Default")
	end
end

local function updateCarry(now: number)
	local ghostId = player:GetAttribute("CarryGhost")
	if ghostId then
		local untilTime = player:GetAttribute("CarryUntil") or now
		carryBanner.Visible = true
		carryBanner.Text = "🏃 " .. Lang.t("StealGo") .. "  " .. Format.time(untilTime - now)
	else
		carryBanner.Visible = false
	end
end

function HUD.start()
	gui = UI.screen("SAG_HUD", 1)
	HUD.gui = gui
	buildTopBar()
	buildColumns()

	-- Pastille "Week-end x2"
	local weekendPill = HUD.pill(UI.Colors.Gold, 3)
	local weekendText = weekendPill:FindFirstChild("Text") :: TextLabel
	weekendText.Text = "🎉 " .. Lang.t("WeekendBoost")
	local function updateWeekend()
		weekendPill.Visible = ReplicatedStorage:GetAttribute("WeekendBoost") == true
	end
	ReplicatedStorage:GetAttributeChangedSignal("WeekendBoost"):Connect(updateWeekend)
	updateWeekend()

	player:GetAttributeChangedSignal("Coins"):Connect(updateCoins)
	player:GetAttributeChangedSignal("Income"):Connect(updateCoins)
	player:GetAttributeChangedSignal("FriendBonus"):Connect(updateCoins)
	updateCoins()

	bonkButton.Activated:Connect(tryBonk)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Q then
			tryBonk()
		end
	end)

	Remotes.get("Notify").OnClientEvent:Connect(function(key: string, params, kind: string)
		HUD.toast(Lang.t(key, params), kind)
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		local now = workspace:GetServerTimeNow()
		updateLock(now)
		updateBonk()
		updateCarry(now)
	end)
end

return HUD
