--[[
	Labels : les étiquettes au-dessus des fantômes (nom, rareté, prix, revenu).
	Elles sont créées par chaque joueur dans SA langue.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local GhostData = require(Shared:WaitForChild("GhostData"))
local Rarities = require(Shared:WaitForChild("Rarities"))

local Lang = require(script.Parent.Lang)
local UI = require(script.Parent.UI)

local Labels = {}

-- mode = "path" (prix + revenu) ou "pedestal" (revenu seulement)
function Labels.ghost(adornee: BasePart, ghostId: string, mode: string, height: number): BillboardGui
	local ghost = GhostData.get(ghostId)
	local rarityColor = Rarities.color(ghost.Rarity)

	local gui = UI.new("BillboardGui", {
		Name = "GhostLabel",
		Size = UDim2.new(9, 0, 2.6, 0), -- en studs : grossit/rapetisse avec la distance
		StudsOffsetWorldSpace = Vector3.new(0, height + 1.7, 0),
		LightInfluence = 0,
		MaxDistance = if mode == "path" then 85 else 45,
		AutoLocalize = Lang.autoLocalize,
		Adornee = adornee,
	})
	UI.label({
		Name = "GhostName",
		Size = UDim2.fromScale(1, 0.4),
		Text = Lang.ghostName(ghostId),
		MaxTextSize = 60,
		Parent = gui,
	})
	local rarityText = string.upper(Lang.rarityName(ghost.Rarity))
	local mutation = GhostData.mutationOf(ghostId)
	if mutation then
		-- variante : "✨ DORÉ x3 • COMMUN"
		rarityText = "✨ " .. string.upper(mutation.Name[Lang.code] or mutation.Name.en) .. " x" .. mutation.Mult .. " • " .. rarityText
		rarityColor = Color3.fromRGB(mutation.Color[1], mutation.Color[2], mutation.Color[3])
	end
	UI.label({
		Name = "Rarity",
		Size = UDim2.fromScale(1, 0.26),
		Position = UDim2.fromScale(0, 0.4),
		Text = rarityText,
		TextColor3 = rarityColor,
		MaxTextSize = 40,
		Parent = gui,
	})
	local price, income = GhostData.priceOf(ghostId), GhostData.incomeOf(ghostId)
	local info = if mode == "path"
		then "🪙 " .. Format.short(price) .. "   +" .. Format.short(income) .. "/s"
		else "+" .. Format.short(income) .. "/s"
	UI.label({
		Name = "Info",
		Size = UDim2.fromScale(1, 0.34),
		Position = UDim2.fromScale(0, 0.66),
		Text = info,
		TextColor3 = UI.Colors.Gold,
		MaxTextSize = 48,
		Parent = gui,
	})
	gui.Parent = adornee
	return gui
end

-- Petite étiquette simple (ex. "!" sur un socle volé, cadenas sur un socle bloqué)
function Labels.simple(adornee: Instance, text: string, color: Color3, offset: Vector3, studsWidth: number?): BillboardGui
	local gui = UI.new("BillboardGui", {
		Size = UDim2.new(studsWidth or 6, 0, 1.6, 0),
		StudsOffsetWorldSpace = offset,
		LightInfluence = 0,
		MaxDistance = 60,
		AutoLocalize = Lang.autoLocalize,
		Adornee = adornee,
	})
	UI.label({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
		MaxTextSize = 60,
		Parent = gui,
	})
	gui.Parent = adornee
	return gui
end

return Labels
