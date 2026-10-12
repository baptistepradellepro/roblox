--[[
	Panels : les fenêtres "Cadeau du jour", "Rebirth" et "Boutique",
	et leurs gros boutons à gauche de l'écran.
	Comme partout, l'interface ne fait que DEMANDER : le serveur vérifie et décide.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Effects = require(script.Parent.Effects)
local HUD = require(script.Parent.HUD)
local Lang = require(script.Parent.Lang)
local UI = require(script.Parent.UI)

local Panels = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local openPanel: Frame? = nil
local dailyInfo = nil
local refreshers: { () -> () } = {}

local function rebirthCost(rebirths: number): number
	return math.floor(Config.RebirthBaseCost * Config.RebirthCostGrowth ^ rebirths)
end

---------------------------------------------------------------- Fenêtre générique

local function close()
	if openPanel then
		openPanel.Visible = false
		openPanel = nil
	end
end

local function open(panel: Frame)
	if openPanel == panel then
		close()
		return
	end
	close()
	panel.Visible = true
	openPanel = panel
	for _, refresh in refreshers do
		refresh()
	end
	UI.pop(panel)
end

local function makePanel(name: string, title: string, color: Color3): (Frame, Frame)
	local panel = UI.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(600, 430),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}, { UI.corner(26), UI.stroke(color, 5) })
	UI.label({
		Size = UDim2.new(1, -120, 0, 56),
		Position = UDim2.fromOffset(60, 10),
		Text = title,
		TextColor3 = color,
		MaxTextSize = 44,
		Parent = panel,
	})
	local closeButton = UI.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = UI.Colors.Bad,
		Text = "✕",
		TextScaled = true,
		Font = UI.Font,
		TextColor3 = UI.Colors.Text,
		AutoButtonColor = true,
		Parent = panel,
	}, { UI.corner(16), UI.stroke(nil, 3) })
	closeButton.Activated:Connect(function()
		Effects.sound("Click")
		close()
	end)
	local body = UI.new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(20, 76),
		Size = UDim2.new(1, -40, 1, -96),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	return panel, body
end

local function actionButton(parent: Instance, text: string, color: Color3, position: UDim2, size: UDim2): (TextButton, TextLabel)
	local button = UI.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = position,
		Size = size,
		BackgroundColor3 = color,
		Text = "",
		AutoButtonColor = true,
		Parent = parent,
	}, { UI.corner(18), UI.stroke(nil, 4) })
	local label = UI.label({
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromOffset(8, 5),
		Text = text,
		MaxTextSize = 36,
		Parent = button,
	})
	return button, label
end

---------------------------------------------------------------- Cadeau du jour

local function buildDaily(): Frame
	local panel, body = makePanel("Daily", "🎁 " .. Lang.t("DailyTitle"), UI.Colors.Gold)
	local grid = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local tiles = {}
	for day = 1, #Config.DailyRewards do
		local tile = UI.new("Frame", {
			Size = UDim2.fromOffset(74, 140),
			BackgroundColor3 = UI.Colors.PanelLight,
			LayoutOrder = day,
			Parent = grid,
		}, { UI.corner(14), UI.stroke(nil, 3) })
		UI.label({ Name = "Day", Size = UDim2.new(1, -6, 0, 26), Position = UDim2.fromOffset(3, 4), Text = Lang.t("DailyDay", { day = day }), MaxTextSize = 20, Parent = tile })
		UI.label({ Name = "Icon", Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 30), Text = if Config.DailyRewards[day].RandomGhostRarity then "👻" else "🪙", MaxTextSize = 38, Parent = tile })
		UI.label({ Name = "Amount", Size = UDim2.new(1, -6, 0, 26), Position = UDim2.fromOffset(3, 76), TextColor3 = UI.Colors.Gold, MaxTextSize = 20, Parent = tile })
		UI.label({ Name = "Extra", Size = UDim2.new(1, -6, 0, 30), Position = UDim2.fromOffset(3, 104), TextColor3 = UI.Colors.Purple, MaxTextSize = 14, Parent = tile })
		tiles[day] = tile
	end

	local claim, claimLabel = actionButton(body, Lang.t("DailyClaim"), UI.Colors.Good, UDim2.new(0.5, 0, 1, -4), UDim2.fromOffset(320, 80))
	claim.Activated:Connect(function()
		if dailyInfo and dailyInfo.CanClaim then
			Effects.sound("Click")
			Remotes.get("ClaimDaily"):FireServer()
		end
	end)

	local function refresh()
		local info = dailyInfo
		if not info then
			return
		end
		local income = player:GetAttribute("Income") or 0
		for day, tile in tiles do
			local reward = Config.DailyRewards[day]
			local amount = math.max(reward.Min, math.floor(income * 60 * reward.Minutes))
			tile.Amount.Text = Format.short(amount)
			tile.Extra.Text = if reward.RandomGhostRarity then Lang.t("DailyGhostBonus") else ""
			local stroke = tile:FindFirstChildOfClass("UIStroke")
			local isToday = day == info.Day
			local done = day < info.Day or (isToday and not info.CanClaim)
			tile.BackgroundColor3 = if isToday then Color3.fromRGB(110, 70, 30) elseif done then UI.Colors.Panel else UI.Colors.PanelLight
			if stroke then
				stroke.Color = if isToday then UI.Colors.Gold else UI.Colors.Stroke
			end
			tile.Icon.Text = if done then "✅" elseif reward.RandomGhostRarity then "👻" else "🪙"
		end
		if info.CanClaim then
			claim.BackgroundColor3 = UI.Colors.Good
			claimLabel.Text = Lang.t("DailyClaim")
		else
			claim.BackgroundColor3 = UI.Colors.Gray
			local wait = (info.NextAt or 0) - workspace:GetServerTimeNow()
			claimLabel.Text = Lang.t("DailyNext", { time = Format.time(wait) })
		end
	end
	table.insert(refreshers, refresh)
	return panel
end

---------------------------------------------------------------- Rebirth

local function buildRebirth(): Frame
	local color = Color3.fromRGB(120, 255, 200)
	local panel, body = makePanel("Rebirth", "♻️ " .. Lang.t("RebirthTitle"), color)
	UI.label({ Size = UDim2.new(1, 0, 0, 34), Text = Lang.t("RebirthDesc"), MaxTextSize = 24, Parent = body })
	local gain = UI.label({ Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 40), TextColor3 = color, MaxTextSize = 34, Parent = body })
	local current = UI.label({ Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 90), TextColor3 = UI.Colors.Info, MaxTextSize = 22, Parent = body })
	local cost = UI.label({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 124), TextColor3 = UI.Colors.Gold, MaxTextSize = 26, Parent = body })

	local bar = UI.new("Frame", {
		Position = UDim2.fromOffset(40, 164),
		Size = UDim2.new(1, -80, 0, 22),
		BackgroundColor3 = UI.Colors.Stroke,
		Parent = body,
	}, { UI.corner(11) })
	local fill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		Parent = bar,
	}, { UI.corner(11) })

	local button, buttonLabel = actionButton(body, Lang.t("RebirthConfirm"), color, UDim2.new(0.5, 0, 1, -4), UDim2.fromOffset(320, 80))
	local armedUntil = 0
	button.Activated:Connect(function()
		local rebirths = player:GetAttribute("Rebirths") or 0
		if (player:GetAttribute("Coins") or 0) < rebirthCost(rebirths) then
			Effects.sound("Error")
			return
		end
		-- double clic obligatoire : on ne perd pas tout par accident
		if os.clock() > armedUntil then
			armedUntil = os.clock() + 3
			buttonLabel.Text = Lang.t("RebirthSure")
			Effects.sound("Click")
			return
		end
		armedUntil = 0
		Remotes.get("Rebirth"):FireServer()
		close()
	end)

	local function refresh()
		local rebirths = player:GetAttribute("Rebirths") or 0
		local coins = player:GetAttribute("Coins") or 0
		local price = rebirthCost(rebirths)
		gain.Text = Lang.t("RebirthGain", { percent = math.floor(Config.RebirthIncomeBonus * 100) })
		current.Text = Lang.t("RebirthCurrent", { mult = 1 + rebirths * Config.RebirthIncomeBonus })
		cost.Text = Lang.t("RebirthCost", { coins = Format.short(price) })
		fill.Size = UDim2.fromScale(math.clamp(coins / price, 0, 1), 1)
		local ready = coins >= price
		button.BackgroundColor3 = if ready then color else UI.Colors.Gray
		if os.clock() > armedUntil then
			buttonLabel.Text = if ready then Lang.t("RebirthConfirm") else Lang.t("RebirthNotEnough", { coins = Format.short(price) })
		end
	end
	table.insert(refreshers, refresh)
	return panel
end

---------------------------------------------------------------- Boutique

local function buildShop(): Frame
	local panel, body = makePanel("Shop", "🛒 " .. Lang.t("ShopTitle"), UI.Colors.Orange)
	local list = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local items = {
		{ Key = "DoubleCoins", Icon = "💰", Title = "ShopDouble", Desc = "ShopDoubleDesc", Id = Config.GamePasses.DoubleCoins, Pass = true, Attribute = "DoubleCoins" },
		{ Key = "LongLock", Icon = "🔒", Title = "ShopLock", Desc = "ShopLockDesc", Id = Config.GamePasses.LongLock, Pass = true, Attribute = "LongLock" },
		{ Key = "CoinPack", Icon = "🪙", Title = "ShopCoins", Desc = "ShopCoinsDesc", Id = Config.Products.CoinPack, Pass = false },
	}

	local updaters = {}
	for order, item in items do
		local card = UI.new("Frame", {
			Size = UDim2.new(1, 0, 0, 96),
			BackgroundColor3 = UI.Colors.PanelLight,
			LayoutOrder = order,
			Parent = list,
		}, { UI.corner(16), UI.stroke(nil, 3) })
		UI.label({ Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(10, 13), Text = item.Icon, MaxTextSize = 54, Parent = card })
		UI.label({ Size = UDim2.new(1, -280, 0, 38), Position = UDim2.fromOffset(90, 10), Text = Lang.t(item.Title), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 30, Parent = card })
		local desc = UI.label({ Size = UDim2.new(1, -280, 0, 34), Position = UDim2.fromOffset(90, 50), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Info, MaxTextSize = 20, Parent = card })
		local buy = UI.new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(170, 70),
			BackgroundColor3 = UI.Colors.Good,
			Text = "",
			Parent = card,
		}, { UI.corner(16), UI.stroke(nil, 3) })
		local price = UI.label({ Size = UDim2.new(1, -12, 1, -10), Position = UDim2.fromOffset(6, 5), Text = "R$ ...", MaxTextSize = 30, Parent = buy })

		local robux: number? = nil
		if item.Id ~= 0 then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(item.Id, if item.Pass then Enum.InfoType.GamePass else Enum.InfoType.Product)
				end)
				if ok and info then
					robux = info.PriceInRobux
				end
			end)
		end

		buy.Activated:Connect(function()
			if item.Id == 0 or (item.Attribute and player:GetAttribute(item.Attribute)) then
				return
			end
			Effects.sound("Click")
			if item.Pass then
				MarketplaceService:PromptGamePassPurchase(player, item.Id)
			else
				MarketplaceService:PromptProductPurchase(player, item.Id)
			end
		end)

		table.insert(updaters, function()
			if item.Key == "CoinPack" then
				local income = player:GetAttribute("Income") or 0
				local amount = math.max(Config.CoinPackMin, math.floor(income * 60 * Config.CoinPackMinutes))
				desc.Text = Lang.t("ShopCoinsDesc", { coins = Format.short(amount) })
			else
				desc.Text = Lang.t(item.Desc)
			end
			if item.Id == 0 then
				buy.BackgroundColor3 = UI.Colors.Gray
				price.Text = Lang.t("ShopSoon")
			elseif item.Attribute and player:GetAttribute(item.Attribute) then
				buy.BackgroundColor3 = UI.Colors.Gray
				price.Text = "✅ " .. Lang.t("ShopOwned")
			else
				buy.BackgroundColor3 = UI.Colors.Good
				price.Text = if robux then "R$ " .. robux else "R$"
			end
		end)
	end

	table.insert(refreshers, function()
		for _, update in updaters do
			update()
		end
	end)
	return panel
end

---------------------------------------------------------------- Démarrage

function Panels.openDaily()
	local panel = gui and gui:FindFirstChild("Daily") :: Frame?
	if panel and openPanel ~= panel then
		open(panel)
	end
end

function Panels.start()
	gui = UI.screen("SAG_Panels", 3)
	local daily = buildDaily()
	local rebirth = buildRebirth()
	local shop = buildShop()

	local column = HUD.leftColumn
	local giftButton = UI.bigButton({ Name = "Gift", Icon = "🎁", Text = Lang.t("Daily"), Color = UI.Colors.Gold, Size = 92, LayoutOrder = 1, Parent = column })
	local rebirthButton = UI.bigButton({ Name = "Rebirth", Icon = "♻️", Text = Lang.t("Rebirth"), Color = Color3.fromRGB(60, 190, 150), Size = 92, LayoutOrder = 2, Parent = column })
	local shopButton = UI.bigButton({ Name = "Shop", Icon = "🛒", Text = Lang.t("Shop"), Color = UI.Colors.Orange, Size = 92, LayoutOrder = 3, Parent = column })

	-- Pastille "!" sur le cadeau quand il est prêt
	local dot = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 0,
		BackgroundColor3 = UI.Colors.Bad,
		Text = "!",
		MaxTextSize = 28,
		Visible = false,
		Parent = giftButton,
	})
	UI.corner(17).Parent = dot

	giftButton.Activated:Connect(function()
		Effects.sound("Click")
		open(daily)
	end)
	rebirthButton.Activated:Connect(function()
		Effects.sound("Click")
		open(rebirth)
	end)
	shopButton.Activated:Connect(function()
		Effects.sound("Click")
		open(shop)
	end)

	local function maybeAutoOpen()
		if dailyInfo and dailyInfo.CanClaim and player:GetAttribute("TutorialDone") then
			task.delay(2, Panels.openDaily)
		end
	end
	Remotes.get("DailyInfo").OnClientEvent:Connect(function(info)
		local first = dailyInfo == nil
		dailyInfo = info
		dot.Visible = info.CanClaim
		if first then
			maybeAutoOpen()
		end
		for _, refresh in refreshers do
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("TutorialDone"):Connect(maybeAutoOpen)

	-- Rafraîchit la fenêtre ouverte (prix, compte à rebours)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if openPanel and accumulator >= 0.5 then
			accumulator = 0
			for _, refresh in refreshers do
				refresh()
			end
		end
	end)
end

return Panels
