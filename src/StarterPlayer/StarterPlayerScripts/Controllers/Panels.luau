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
local GhostData = require(Shared:WaitForChild("GhostData"))
local GhostFactory = require(Shared:WaitForChild("GhostFactory"))
local Missions = require(Shared:WaitForChild("Missions"))
local Monsters = require(Shared:WaitForChild("Monsters"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Shop = require(Shared:WaitForChild("Shop"))
local Strings = require(Shared:WaitForChild("Strings"))
local Weapons = require(Shared:WaitForChild("Weapons"))
local Wheel = require(Shared:WaitForChild("Wheel"))

local Effects = require(script.Parent.Effects)
local HUD = require(script.Parent.HUD)
local Lang = require(script.Parent.Lang)
local UI = require(script.Parent.UI)

local Panels = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local openPanel: Frame? = nil
local dailyInfo = nil
local indexInfo = nil
local missionsInfo = nil
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

local IS_STUDIO = RunService:IsStudio()

-- La roue est-elle assez près pour tourner ? (on joue devant elle, tout le monde regarde)
local function nearWheel(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local map = workspace:FindFirstChild("Map")
	local anchor = map and map:FindFirstChild("FortuneWheelAnchor", true) :: BasePart?
	return root ~= nil and anchor ~= nil and (root.Position - anchor.Position).Magnitude < 45
end

local shopSelect: ((string) -> ())? = nil

-- L'icône d'un article : une image importée (Config.ShopIcons), sinon l'emoji
local function iconFor(id: string, emoji: string): string
	local image = Config.ShopIcons and Config.ShopIcons[id]
	return if type(image) == "string" and image ~= "" then image else emoji
end

local function buildShop(): Frame
	local panel, body = makePanel("Shop", "🛒 " .. Lang.t("ShopTitle"), UI.Colors.Orange)
	panel.Size = UDim2.fromOffset(660, 480)

	-- les onglets
	local tabs = UI.new("Frame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, 54),
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
	local content = UI.new("ScrollingFrame", {
		Name = "Content",
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 1, -62),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = body,
	})

	local categories = table.clone(Shop.Categories)
	table.insert(categories, { Id = "Codes", Icon = "🎟️", Name = { fr = "Codes", en = "Codes" } })
	local pages: { [string]: Frame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local updaters = {}

	local function selectTab(id: string)
		for key, page in pages do
			page.Visible = key == id
		end
		for key, button in tabButtons do
			button.BackgroundColor3 = if key == id then UI.Colors.Orange else UI.Colors.PanelLight
		end
		content.CanvasPosition = Vector2.zero
	end
	shopSelect = selectTab

	for order, category in categories do
		local tab = UI.new("TextButton", {
			Name = "Tab_" .. category.Id,
			Size = UDim2.new(1 / #categories, -6, 1, 0),
			BackgroundColor3 = UI.Colors.PanelLight,
			Text = "",
			LayoutOrder = order,
			Parent = tabs,
		}, { UI.corner(14), UI.stroke(nil, 3) })
		UI.label({
			Size = UDim2.new(1, -6, 1, -6),
			Position = UDim2.fromOffset(3, 3),
			Text = category.Icon .. " " .. Lang.pick(category.Name),
			MaxTextSize = 20,
			Parent = tab,
		})
		tab.Activated:Connect(function()
			Effects.sound("Click")
			selectTab(category.Id)
		end)
		tabButtons[category.Id] = tab
		pages[category.Id] = UI.new("Frame", {
			Name = "Page_" .. category.Id,
			Size = UDim2.new(1, -12, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = false,
			Parent = content,
		}, {
			UI.new("UIListLayout", {
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	end

	-- Une carte : icône, titre, description, et un bouton à droite (optionnel)
	local function card(page: Frame, order: number, icon: string, title: string, withButton: boolean, height: number?)
		local frame = UI.new("Frame", {
			Size = UDim2.new(1, 0, 0, height or 76),
			BackgroundColor3 = UI.Colors.PanelLight,
			LayoutOrder = order,
			Parent = page,
		}, { UI.corner(16), UI.stroke(nil, 3) })
		local right = if withButton then 190 else 20
		if string.sub(icon, 1, 13) == "rbxassetid://" then
			UI.new("ImageLabel", {
				Name = "IconImage",
				Size = UDim2.fromOffset(58, 58),
				Position = UDim2.fromOffset(8, 9),
				BackgroundTransparency = 1,
				Image = icon,
				ScaleType = Enum.ScaleType.Fit,
				Parent = frame,
			})
		else
			UI.label({ Size = UDim2.fromOffset(58, 58), Position = UDim2.fromOffset(8, 9), Text = icon, MaxTextSize = 44, Parent = frame })
		end
		UI.label({
			Name = "Title",
			Size = UDim2.new(1, -(74 + right), 0, 30),
			Position = UDim2.fromOffset(72, 6),
			Text = title,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 26,
			Parent = frame,
		})
		local desc = UI.label({
			Name = "Desc",
			Size = UDim2.new(1, -(74 + right), 1, -42),
			Position = UDim2.fromOffset(72, 38),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = UI.Colors.Info,
			MaxTextSize = 18,
			Parent = frame,
		})
		local button, label = nil, nil
		if withButton then
			button = UI.new("TextButton", {
				Name = "Buy",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(170, 56),
				BackgroundColor3 = UI.Colors.Good,
				Text = "",
				Parent = frame,
			}, { UI.corner(16), UI.stroke(nil, 3) })
			label = UI.label({ Size = UDim2.new(1, -12, 1, -10), Position = UDim2.fromOffset(6, 5), MaxTextSize = 26, Parent = button })
		end
		return frame, desc, button, label
	end

	-- Le bouton d'achat d'un article Robux (prix, "Acheté", "Bientôt", test gratuit dans Studio)
	local function itemCard(page: Frame, order: number, item, icon: string, title: string, describe: () -> string)
		local _, desc, button, label = card(page, order, icon, title, true)
		local id = Shop.idOf(item, Config)
		local robux: number? = nil
		if id ~= 0 then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(id, if item.Kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
				end)
				if ok and info then
					robux = info.PriceInRobux
				end
			end)
		end
		local enabled = false
		button.Activated:Connect(function()
			if enabled then
				Effects.sound("Click")
				Remotes.get("ShopBuy"):FireServer(item.Key)
			end
		end)
		table.insert(updaters, function()
			desc.Text = describe()
			local color = UI.Colors.Good
			enabled = false
			if item.Kind == "Pass" and player:GetAttribute(item.Attribute) then
				label.Text = "✅ " .. Lang.t("ShopOwned")
				color = UI.Colors.Gray
			elseif item.Random and player:GetAttribute("RandomItemsRestricted") ~= false then
				label.Text = Lang.t("ShopRestrictedShort")
				color = UI.Colors.Gray
			elseif id == 0 then
				if IS_STUDIO then
					label.Text = "🧪 " .. Lang.t("ShopTestFree")
					enabled = true
				else
					label.Text = Lang.t("ShopSoon")
					color = UI.Colors.Gray
				end
			else
				label.Text = "R$ " .. tostring(robux or item.Robux)
				enabled = true
			end
			button.BackgroundColor3 = color
		end)
	end

	---- Passes
	local order = 0
	for _, item in Shop.Items do
		order += 1
		if item.Category == "Passes" then
			itemCard(pages.Passes, order, item, item.Icon, Lang.pick(item.Name), function()
				return Lang.pick(item.Desc)
			end)
		elseif item.Category == "Coins" then
			itemCard(pages.Coins, order, item, item.Icon, Lang.pick(item.Name), function()
				local income = player:GetAttribute("Income") or 0
				local amount = math.max(Config.CoinPackMin, math.floor(income * 60 * Config.CoinPackMinutes))
				return Strings.fill(Lang.pick(item.Desc), { coins = Format.short(amount) })
			end)
		end
	end

	---- Armes : la Batte offerte, puis les armes Game Pass
	for _, weapon in Weapons.List do
		local stats = Lang.t("WeaponStats", { range = weapon.Range, cooldown = weapon.Cooldown })
		local function describe(): string
			return Lang.pick(weapon.Desc) .. "\n" .. stats .. (if weapon.Sweep then " · " .. Lang.t("WeaponSweep") else "")
		end
		if weapon.Free then
			local _, desc = card(pages.Weapons, weapon.Order, iconFor(weapon.Id, weapon.Icon), Lang.pick(weapon.Name) .. "  ✅ " .. Lang.t("ShopFree"), false, 84)
			desc.Text = describe()
		else
			for _, item in Shop.Items do
				if item.Weapon == weapon.Id then
					itemCard(pages.Weapons, weapon.Order, item, iconFor(weapon.Id, weapon.Icon), Lang.pick(weapon.Name), describe)
				end
			end
		end
	end

	---- Monstres
	for _, item in Shop.Items do
		local monster = item.Monster and Monsters.get(item.Monster)
		if monster then
			itemCard(pages.Monsters, monster.Order + 1, item, iconFor(monster.Id, monster.Icon), Lang.pick(monster.Name), function()
				return Lang.pick(monster.Desc) .. "\n" .. Lang.t("MonsterStats", { time = Format.time(monster.Duration) })
			end)
		end
	end
	local _, monsterInfo = card(pages.Monsters, 0, "👹", Lang.t("MonstersTitle"), false, 70)
	monsterInfo.Text = Lang.t("MonstersInfo")

	---- Roue de la Fortune : tours possédés, chances, achat
	local spinCard, spinDesc, spinButton, spinLabel = card(pages.Wheel, 1, iconFor("Wheel", "🎡"), Lang.t("WheelTitle"), true)
	spinButton.Name = "SpinButton"
	spinCard.Name = "SpinCard"
	spinButton.Activated:Connect(function()
		if (player:GetAttribute("Spins") or 0) <= 0 then
			return
		end
		Effects.sound("Click")
		if not nearWheel() then
			HUD.toast(Lang.t("WheelGoThere"), "info")
			return
		end
		Remotes.get("SpinWheel"):FireServer()
		close()
	end)
	table.insert(updaters, function()
		local spins = player:GetAttribute("Spins") or 0
		spinDesc.Text = Lang.t("WheelSpins", { count = spins })
		spinLabel.Text = Lang.t("WheelSpin")
		spinButton.BackgroundColor3 = if spins > 0 then UI.Colors.Gold else UI.Colors.Gray
	end)

	local oddsHeight = 44 + #Wheel.Segments * 26
	local oddsCard = card(pages.Wheel, 2, "🎲", Lang.t("WheelOdds"), false, oddsHeight)
	oddsCard.Name = "OddsCard"
	local total = Wheel.totalChance()
	for index, segment in Wheel.Segments do
		local percent = math.floor(segment.Chance / total * 1000 + 0.5) / 10
		UI.label({
			Name = "Odds_" .. segment.Id,
			Size = UDim2.new(1, -90, 0, 24),
			Position = UDim2.fromOffset(72, 38 + (index - 1) * 26),
			Text = segment.Icon .. "  " .. Lang.t("Wheel_" .. segment.Id) .. "  :  " .. Format.percent(percent),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 20,
			Parent = oddsCard,
		})
	end
	for _, item in Shop.Items do
		if item.Category == "Wheel" then
			itemCard(pages.Wheel, 2 + item.Order, item, item.Icon, Lang.pick(item.Name), function()
				if player:GetAttribute("RandomItemsRestricted") ~= false then
					return Lang.t("ShopRestricted")
				end
				return Lang.pick(item.Desc)
			end)
		end
	end

	---- Codes secrets : le joueur tape le code, le serveur vérifie tout
	local codeCard = card(pages.Codes, 1, "🎟️", Lang.t("Codes"), false)
	local codeDesc = codeCard:FindFirstChild("Desc") :: TextLabel
	codeDesc.Text = Lang.t("CodesDesc")
	codeDesc.Size = UDim2.new(1, -340, 1, -42)
	local title = codeCard:FindFirstChild("Title") :: TextLabel
	title.Size = UDim2.new(1, -340, 0, 30)
	local codeBox = UI.new("TextBox", {
		Name = "CodeBox",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -96, 0.5, 0),
		Size = UDim2.fromOffset(170, 50),
		BackgroundColor3 = UI.Colors.Panel,
		PlaceholderText = Lang.t("CodePlaceholder"),
		PlaceholderColor3 = UI.Colors.Gray,
		Text = "",
		ClearTextOnFocus = false,
		Font = UI.Font,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		Parent = codeCard,
	}, { UI.corner(12), UI.stroke(nil, 2) })
	local codeButton = UI.new("TextButton", {
		Name = "CodeButton",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(78, 50),
		BackgroundColor3 = UI.Colors.Purple,
		Text = "",
		Parent = codeCard,
	}, { UI.corner(12), UI.stroke(nil, 3) })
	UI.label({ Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5), Text = Lang.t("CodeRedeem"), MaxTextSize = 28, Parent = codeButton })
	codeButton.Activated:Connect(function()
		local code = codeBox.Text
		if #code > 0 and #code <= 30 then
			Effects.sound("Click")
			Remotes.get("RedeemCode"):FireServer(code)
			codeBox.Text = ""
		end
	end)

	selectTab("Passes")
	table.insert(refreshers, function()
		for _, update in updaters do
			update()
		end
	end)
	return panel
end

---------------------------------------------------------------- Fantômédex

local function buildIndex(): Frame
	local panel, body = makePanel("Index", "📖 " .. Lang.t("IndexTitle"), UI.Colors.Purple)

	-- Progression par rareté en haut
	local chips = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local chipLabels = {}
	for order, rarity in Rarities.Order do
		local chip = UI.new("Frame", {
			Size = UDim2.fromOffset(88, 30),
			BackgroundColor3 = UI.Colors.Panel,
			LayoutOrder = order,
			Parent = chips,
		}, { UI.corner(10), UI.stroke(Rarities.color(rarity), 2) })
		chipLabels[rarity] = UI.label({
			Size = UDim2.new(1, -8, 1, -6),
			Position = UDim2.fromOffset(4, 3),
			TextColor3 = Rarities.color(rarity),
			MaxTextSize = 16,
			Parent = chip,
		})
	end

	-- Grille des 32 fantômes (construite à la première ouverture)
	local grid = UI.new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 1, -84),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = body,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(100, 112),
			CellPadding = UDim2.fromOffset(8, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local info = UI.label({
		Name = "Info",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 42),
		TextColor3 = UI.Colors.Gold,
		MaxTextSize = 22,
		TextWrapped = true,
		Parent = body,
	})

	local tiles = {}
	local selected: string? = nil

	local function isFound(ghostId: string): boolean
		return indexInfo ~= nil and table.find(indexInfo.Discovered, ghostId) ~= nil
	end

	local function buildTiles()
		for _, ghost in GhostData.List do
			local tile = UI.new("TextButton", {
				Name = ghost.Id,
				BackgroundColor3 = UI.Colors.PanelLight,
				Text = "",
				AutoButtonColor = true,
				LayoutOrder = ghost.Order,
				Parent = grid,
			}, { UI.corner(14), UI.stroke(Rarities.color(ghost.Rarity), 3) })
			local viewport = UI.new("ViewportFrame", {
				Size = UDim2.new(1, -8, 0, 80),
				Position = UDim2.fromOffset(4, 4),
				BackgroundTransparency = 1,
				Ambient = Color3.fromRGB(190, 190, 200),
				LightColor = Color3.fromRGB(255, 255, 255),
				LightDirection = Vector3.new(-1, -1, 1),
				Parent = tile,
			})
			local model = GhostFactory.build(ghost.Id)
			model.Parent = viewport
			local cf, size = model:GetBoundingBox()
			local distance = math.max(size.X, size.Y) * 1.5 + 2
			local camera = Instance.new("Camera")
			camera.FieldOfView = 40
			camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(distance * 0.3, size.Y * 0.1, -distance), cf.Position)
			camera.Parent = viewport
			viewport.CurrentCamera = camera
			local name = UI.label({
				Size = UDim2.new(1, -6, 0, 24),
				Position = UDim2.new(0, 3, 1, -27),
				MaxTextSize = 16,
				Parent = tile,
			})
			tile.Activated:Connect(function()
				Effects.sound("Click")
				selected = ghost.Id
				for _, refresh in refreshers do
					refresh()
				end
			end)
			tiles[ghost.Id] = { Viewport = viewport, Name = name }
		end
	end

	local function refresh()
		if not panel.Visible then
			return
		end
		if next(tiles) == nil then
			buildTiles()
		end
		for _, rarity in Rarities.Order do
			local list = GhostData.ByRarity[rarity] or {}
			local found = 0
			for _, ghost in list do
				if isFound(ghost.Id) then
					found += 1
				end
			end
			local done = indexInfo and indexInfo.Rewarded and indexInfo.Rewarded[rarity]
			chipLabels[rarity].Text = Lang.rarityName(rarity) .. " " .. found .. "/" .. #list .. (if done then " ✅" else "")
		end
		for ghostId, tile in tiles do
			local found = isFound(ghostId)
			-- pas encore trouvé : silhouette noire et "???"
			tile.Viewport.ImageColor3 = if found then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
			tile.Name.Text = if found then Lang.ghostName(ghostId) else Lang.t("IndexUnknown")
		end
		local percent = math.floor(Config.IndexCompleteBonus * 100)
		if selected then
			local ghost = GhostData.get(selected)
			if isFound(selected) then
				info.Text = Lang.t("IndexCard", { ghost = selected, gag = Lang.ghostGag(selected) })
					.. "  (+" .. Format.short(ghost.Income) .. "/s)"
			else
				info.Text = Lang.rarityName(ghost.Rarity) .. " : " .. Lang.t("IndexUnknownHint")
			end
		elseif indexInfo and indexInfo.Complete then
			info.Text = "🏆 " .. Lang.t("IndexBonusDone", { percent = percent })
		else
			info.Text = Lang.t("IndexBonus", { percent = percent }) .. "  •  " .. Lang.t("IndexHint")
		end
	end
	table.insert(refreshers, refresh)
	return panel
end

---------------------------------------------------------------- Missions du jour

local TIER_COLORS = {
	easy = Color3.fromRGB(80, 220, 120),
	medium = Color3.fromRGB(255, 190, 40),
	hard = Color3.fromRGB(255, 80, 90),
}

local function buildMissions(): Frame
	local panel, body = makePanel("Missions", "📋 " .. Lang.t("MissionsTitle"), UI.Colors.Info)
	panel.Size = UDim2.fromOffset(600, 490)
	local title = panel:FindFirstChildOfClass("TextLabel")
	local mode = "daily"

	-- deux onglets : missions du jour, défis de la semaine
	local tabs = {}
	for i, info in { { "daily", "MissionsTabDaily" }, { "weekly", "MissionsTabWeekly" } } do
		local tab = UI.new("TextButton", {
			Name = if info[1] == "daily" then "TabDaily" else "TabWeekly",
			Size = UDim2.new(0.5, -6, 0, 44),
			Position = UDim2.new((i - 1) * 0.5, (i - 1) * 6, 0, 0),
			BackgroundColor3 = UI.Colors.PanelLight,
			Text = "",
			Parent = body,
		}, { UI.corner(14), UI.stroke(nil, 3) })
		UI.label({ Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), Text = Lang.t(info[2]), MaxTextSize = 22, Parent = tab })
		tabs[info[1]] = tab
	end

	local cards = {}
	for i = 1, 3 do
		local card = UI.new("Frame", {
			Name = "Mission" .. i,
			Size = UDim2.new(1, 0, 0, 72),
			Position = UDim2.fromOffset(0, 52 + (i - 1) * 80),
			BackgroundColor3 = UI.Colors.PanelLight,
			Parent = body,
		}, { UI.corner(16), UI.stroke(nil, 3) })
		local icon = UI.label({ Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(8, 8), MaxTextSize = 44, Parent = card })
		local tier = UI.label({ Size = UDim2.fromOffset(110, 22), Position = UDim2.fromOffset(72, 4), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 18, Parent = card })
		local text = UI.label({ Name = "Text", Size = UDim2.new(1, -230, 0, 26), Position = UDim2.fromOffset(72, 24), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 22, Parent = card })
		local bar = UI.new("Frame", {
			Position = UDim2.fromOffset(72, 54),
			Size = UDim2.new(1, -230, 0, 10),
			BackgroundColor3 = UI.Colors.Stroke,
			Parent = card,
		}, { UI.corner(5) })
		local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.Colors.Good, Parent = bar }, { UI.corner(5) })
		local count = UI.label({ Name = "Count", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -110, 0, 18), Size = UDim2.fromOffset(110, 40), MaxTextSize = 26, Parent = card })
		local reward = UI.label({ Name = "Reward", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 18), Size = UDim2.fromOffset(100, 40), TextColor3 = UI.Colors.Gold, MaxTextSize = 26, Parent = card })
		cards[i] = { Icon = icon, Tier = tier, Text = text, Fill = fill, Count = count, Reward = reward }
	end
	local bonus = UI.label({ Name = "Bonus", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 296), TextColor3 = UI.Colors.Gold, MaxTextSize = 24, Parent = body })
	local footer = UI.label({ Name = "Footer", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 336), TextColor3 = UI.Colors.Info, MaxTextSize = 20, Parent = body })

	local function refresh()
		local info = missionsInfo
		if not info or not panel.Visible then
			return
		end
		for key, tab in tabs do
			tab.BackgroundColor3 = if key == mode then UI.Colors.Info else UI.Colors.PanelLight
		end
		if title then
			title.Text = if mode == "daily" then "📋 " .. Lang.t("MissionsTitle") else "🏆 " .. Lang.t("WeeklyTitle")
		end
		local weekly = mode == "weekly"
		local source = if weekly then info.Weekly else info
		local defs = if weekly then Missions.WeeklyDefs else Missions.Defs
		if not source then
			return
		end
		local income = player:GetAttribute("Income") or 0
		for i, card in cards do
			local mission = source.List[i]
			if mission then
				local def = defs[mission.Id] or {}
				local n = if mission.Id == "Earn" then Format.short(mission.Target) else mission.Target
				local reward = if weekly then Missions.weeklyReward(income) else Missions.reward(mission.Tier, income)
				card.Icon.Text = if mission.Done then "✅" else (def.Icon or "⭐")
				card.Tier.Text = Lang.t("MissionTier_" .. mission.Tier)
				card.Tier.TextColor3 = TIER_COLORS[mission.Tier] or UI.Colors.Gold
				card.Text.Text = Lang.t((if weekly then "Weekly_" else "Mission_") .. mission.Id, { n = n })
				card.Fill.Size = UDim2.fromScale(math.clamp(mission.Progress / mission.Target, 0, 1), 1)
				card.Count.Text = if mission.Id == "Earn"
					then Format.short(mission.Progress) .. "/" .. Format.short(mission.Target)
					else mission.Progress .. "/" .. mission.Target
				card.Reward.Text = if mission.Done then "✅" else "🪙 " .. Format.short(reward)
			end
		end
		local remaining = math.max(0, (source.ResetAt or 0) - workspace:GetServerTimeNow())
		if weekly then
			bonus.Text = if source.BonusDone then Lang.t("WeeklyBonusDone") else Lang.t("WeeklyBonus")
			footer.Text = Lang.t("WeeklyNext", { days = math.floor(remaining / 86400), hours = math.floor(remaining % 86400 / 3600) })
		else
			bonus.Text = if source.BonusDone
				then Lang.t("MissionsBonusDone")
				else Lang.t("MissionsBonus", { coins = Format.short(Missions.reward("bonus", income)) })
			footer.Text = Lang.t("MissionsNext", { time = Format.time(remaining) })
		end
	end
	for key, tab in tabs do
		tab.Activated:Connect(function()
			Effects.sound("Click")
			mode = key
			refresh()
		end)
	end
	table.insert(refreshers, refresh)
	return panel
end

---------------------------------------------------------------- Démarrage

-- Ouvre la boutique sur un onglet ("Passes", "Weapons", "Wheel", "Monsters", "Coins", "Codes")
function Panels.openShop(category: string?)
	local panel = gui and gui:FindFirstChild("Shop") :: Frame?
	if not panel then
		return
	end
	if openPanel ~= panel then
		open(panel)
	end
	if shopSelect then
		shopSelect(category or "Passes")
	end
end

function Panels.openDaily()
	local panel = gui and gui:FindFirstChild("Daily") :: Frame?
	if panel and openPanel ~= panel then
		open(panel)
	end
end

function Panels.start()
	gui = UI.screen("SAG_Panels", 3)
	local daily = buildDaily()
	local missions = buildMissions()
	local index = buildIndex()
	local rebirth = buildRebirth()
	local shop = buildShop()

	local column = HUD.leftColumn
	local size = 76
	local giftButton = UI.bigButton({ Name = "Gift", Icon = "🎁", Text = Lang.t("Daily"), Color = UI.Colors.Gold, Size = size, LayoutOrder = 1, Parent = column })
	local missionsButton = UI.bigButton({ Name = "MissionsButton", Icon = "📋", Text = Lang.t("Missions"), Color = UI.Colors.Info, Size = size, LayoutOrder = 2, Parent = column })
	local indexButton = UI.bigButton({ Name = "Index", Icon = "📖", Text = Lang.t("Index"), Color = UI.Colors.Purple, Size = size, LayoutOrder = 3, Parent = column })
	local rebirthButton = UI.bigButton({ Name = "Rebirth", Icon = "♻️", Text = Lang.t("Rebirth"), Color = Color3.fromRGB(60, 190, 150), Size = size, LayoutOrder = 4, Parent = column })
	local shopButton = UI.bigButton({ Name = "Shop", Icon = "🛒", Text = Lang.t("Shop"), Color = UI.Colors.Orange, Size = size, LayoutOrder = 5, Parent = column })

	-- Pastille rouge sur un bouton (cadeau prêt, nouveau fantôme...)
	local function makeDot(parent: Instance, text: string): TextLabel
		local dot = UI.label({
			Name = "Dot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(34, 34),
			BackgroundTransparency = 0,
			BackgroundColor3 = UI.Colors.Bad,
			Text = text,
			MaxTextSize = 28,
			Visible = false,
			Parent = parent,
		})
		UI.corner(17).Parent = dot
		return dot
	end
	local dot = makeDot(giftButton, "!")
	local indexDot = makeDot(indexButton, "!")
	local missionsDot = makeDot(missionsButton, "!")
	local seenMissionsDay = nil

	missionsButton.Activated:Connect(function()
		Effects.sound("Click")
		missionsDot.Visible = false
		seenMissionsDay = missionsInfo and missionsInfo.Day
		open(missions)
	end)
	Remotes.get("MissionsInfo").OnClientEvent:Connect(function(info)
		missionsInfo = info
		-- point rouge : nouvelles missions pas encore regardées
		missionsDot.Visible = info.Day ~= seenMissionsDay and not info.BonusDone
		for _, refresh in refreshers do
			refresh()
		end
	end)

	giftButton.Activated:Connect(function()
		Effects.sound("Click")
		open(daily)
	end)
	indexButton.Activated:Connect(function()
		Effects.sound("Click")
		indexDot.Visible = false
		open(index)
	end)
	Remotes.get("IndexInfo").OnClientEvent:Connect(function(info)
		local previous = if indexInfo then #indexInfo.Discovered else nil
		indexInfo = info
		if previous and #info.Discovered > previous and openPanel ~= index then
			indexDot.Visible = true
		end
		for _, refresh in refreshers do
			refresh()
		end
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
	for _, attribute in { "Spins", "RandomItemsRestricted" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if openPanel then
				for _, refresh in refreshers do
					refresh()
				end
			end
		end)
	end

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
