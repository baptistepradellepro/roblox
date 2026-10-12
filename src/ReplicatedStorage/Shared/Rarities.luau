--[[
	Rarities : les raretés, leurs couleurs et leurs chances d'apparition.
	DayWeight / NightWeight = "poids" : plus le nombre est grand, plus c'est fréquent.
	Event = la rareté n'apparaît que pendant cet événement (et seulement la nuit).
	Bonus = série en plus : pas besoin de l'avoir pour compléter le Fantômédex.
]]

local Rarities = {}

Rarities.Order = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Halloween", "Frost" }

Rarities.Info = {
	Common = { Rank = 1, Color = { 190, 196, 210 }, Scale = 0.85, DayWeight = 55, NightWeight = 38 },
	Rare = { Rank = 2, Color = { 70, 160, 255 }, Scale = 1.0, DayWeight = 30, NightWeight = 30 },
	Epic = { Rank = 3, Color = { 175, 90, 255 }, Scale = 1.15, DayWeight = 11, NightWeight = 16 },
	Legendary = { Rank = 4, Color = { 255, 190, 40 }, Scale = 1.3, DayWeight = 3.6, NightWeight = 8 },
	Mythic = { Rank = 5, Color = { 255, 60, 130 }, Scale = 1.6, DayWeight = 0.4, NightWeight = 4 },
	-- Secret : presque jamais (environ une fois toutes les quelques heures par serveur)
	Secret = { Rank = 7, Color = { 225, 240, 255 }, Scale = 1.8, DayWeight = 0.012, NightWeight = 0.05, Bonus = true },
	-- Halloween et Givré : seulement la nuit, et seulement pendant leur événement
	Halloween = { Rank = 6, Color = { 255, 125, 20 }, Scale = 1.4, DayWeight = 0, NightWeight = 4, EventOnly = true, Event = "Halloween" },
	Frost = { Rank = 6, Color = { 120, 210, 255 }, Scale = 1.4, DayWeight = 0, NightWeight = 4, EventOnly = true, Event = "Winter" },
}

function Rarities.rank(rarity: string): number
	local info = Rarities.Info[rarity]
	return info and info.Rank or 0
end

function Rarities.color(rarity: string): Color3
	local c = Rarities.Info[rarity].Color
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Tire une rareté au hasard. roll = nombre entre 0 et 1.
-- events = les événements en cours, ex. { Halloween = true } (true seul = Halloween)
function Rarities.roll(roll: number, isNight: boolean, events: any): string
	local active = if type(events) == "table" then events else { Halloween = events == true }
	local total = 0
	local weights = {}
	for _, name in Rarities.Order do
		local info = Rarities.Info[name]
		local w = if isNight then info.NightWeight else info.DayWeight
		if info.EventOnly and not active[info.Event] then
			w = 0
		end
		weights[name] = w
		total += w
	end
	local target = roll * total
	local acc = 0
	for _, name in Rarities.Order do
		acc += weights[name]
		if target < acc then
			return name
		end
	end
	return "Common"
end

return Rarities
