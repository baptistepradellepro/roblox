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

local Shared = ReplicatedStorage:WaitForChild("Shared")
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
local lockPill: Frame
local lockText: TextLabel
local carryBanner: TextLabel
local shownCoins = 0

-- Petite pastille d'info (ex. minuteur de nuit) dans la ligne sous les pièces
function HUD.pill(color: Color3, order: number): Frame
	local pill = UI.new("Frame", {
		Name = "Pill",
		Size = UDim2.fromOffset(180, 34),
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
	-- Infos sous les pièces (minuteur de nuit, bonus amis...) : 3 pastilles par ligne au plus
	HUD.infoRow = UI.new("Frame", {
		Name = "InfoRow",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 94),
		Size = UDim2.fromOffset(556, 76),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(180, 34),
			CellPadding = UDim2.fromOffset(8, 8),
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local friendPill = HUD.pill(UI.Colors.Info, 2)
	friendLabel = friendPill:FindFirstChild("Text") :: TextLabel

	toastList = UI.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 178),
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
		Position = UDim2.new(0, 12, 0.47, 0),
		Size = UDim2.fromOffset(92, 430),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
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

-- Pastille d'état du verrou (on verrouille avec le bouton au fond de sa base, pas ici)
local function updateLock(now: number)
	local base = myBase()
	if not base then
		lockPill.Visible = false
		return
	end
	lockPill.Visible = true
	local lockedUntil = base:GetAttribute("LockedUntil") or 0
	local readyAt = base:GetAttribute("LockReadyAt") or 0
	if now < lockedUntil then
		local key = if base:GetAttribute("Shield") then "ShieldPill" else "LockPillOn"
		local icon = if base:GetAttribute("Shield") then "🛡️ " else "🔒 "
		lockText.Text = icon .. Lang.t(key, { time = Format.time(lockedUntil - now) })
	elseif now < readyAt then
		lockText.Text = "⏳ " .. Lang.t("LockPillCooldown", { time = Format.time(readyAt - now) })
	else
		lockText.Text = "🔒 " .. Lang.t("LockPillReady")
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

	-- Pastille d'état du verrou
	lockPill = HUD.pill(UI.Colors.Info, -1)
	lockPill.Name = "LockPill"
	lockText = lockPill:FindFirstChild("Text") :: TextLabel

	-- Pastille "pièces à récupérer" (sur les plaques vertes de ta base)
	local storedPill = HUD.pill(UI.Colors.Good, 0)
	local storedText = storedPill:FindFirstChild("Text") :: TextLabel
	local function updateStored()
		local stored = player:GetAttribute("Stored") or 0
		storedPill.Visible = stored >= 1
		storedText.Text = "💰 " .. Lang.t("StoredPill", { coins = Format.short(stored) })
	end
	player:GetAttributeChangedSignal("Stored"):Connect(updateStored)
	updateStored()

	-- Pastille "Revenus x2" gagnée à la Roue de la Fortune
	local boostPill = HUD.pill(UI.Colors.Info, 2)
	boostPill.Name = "BoostPill"
	local boostText = boostPill:FindFirstChild("Text") :: TextLabel
	local boostShown = -1
	RunService.Heartbeat:Connect(function()
		local remaining = math.ceil((player:GetAttribute("BoostUntil") or 0) - workspace:GetServerTimeNow())
		if remaining == boostShown then
			return -- le texte ne change qu'une fois par seconde
		end
		boostShown = remaining
		boostPill.Visible = remaining > 0
		if remaining > 0 then
			boostText.Text = "⚡ " .. Lang.t("BoostPill", { time = Format.time(remaining) })
		end
	end)

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
		updateCarry(now)
	end)
end

return HUD
