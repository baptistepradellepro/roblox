--[[
	Missions : les missions du jour (partagé entre le serveur et les joueurs).
	Chaque jour, chaque joueur reçoit 3 missions : une facile, une moyenne, une difficile.
	Les missions changent à minuit UTC. Récompense en pièces (calculée selon le revenu
	du joueur au moment où il réussit), et un bonus quand les 3 sont faites.
]]

local Missions = {}

Missions.Tiers = { "easy", "medium", "hard" }

-- Les missions possibles pour chaque difficulté
Missions.Pool = {
	easy = { "Buy", "Earn", "Lock" },
	medium = { "Sell", "BuyRare", "NightOutside" },
	hard = { "Steal", "Bonk", "BuyEpic" },
}

-- Target = objectif (Earn est calculé selon le revenu), Icon = emoji affiché
Missions.Defs = {
	Buy = { Target = 3, Icon = "🛒" },
	Earn = { Icon = "🪙" },
	Lock = { Target = 1, Icon = "🔒" },
	Sell = { Target = 2, Icon = "💰" },
	BuyRare = { Target = 1, Icon = "💎", MinRarity = "Rare" },
	NightOutside = { Target = 30, Icon = "🌙" },
	Steal = { Target = 1, Icon = "🦹" },
	Bonk = { Target = 1, Icon = "🔨" },
	BuyEpic = { Target = 1, Icon = "✨", MinRarity = "Epic" },
}

-- Récompense = X minutes de revenus, avec un minimum
Missions.Rewards = {
	easy = { Minutes = 3, Min = 300 },
	medium = { Minutes = 5, Min = 600 },
	hard = { Minutes = 8, Min = 1200 },
	bonus = { Minutes = 10, Min = 2000 },
}

function Missions.reward(tier: string, incomePerSecond: number): number
	local r = Missions.Rewards[tier] or Missions.Rewards.easy
	return math.max(r.Min, math.floor(incomePerSecond * 60 * r.Minutes))
end

-- Objectif de la mission "Gagne X pièces" : environ 10 minutes de revenus
function Missions.earnTarget(incomePerSecond: number): number
	return math.max(500, math.floor(incomePerSecond * 600))
end

function Missions.today(t: number): number
	return t // 86400
end

---------------------------------------------------------------- Défis de la semaine

-- Plus longs que les missions du jour. 3 défis par semaine, du lundi 0h UTC au
-- dimanche soir. Chaque défi réussi rapporte des pièces, et les 3 réussis donnent
-- un fantôme Épique Doré (payé en pièces si la base est pleine).
Missions.WeeklyDefs = {
	Steal = { Target = 15, Icon = "🦹" },
	Bonk = { Target = 10, Icon = "🏏" },
	Trap = { Target = 5, Icon = "🍌" },
	Buy = { Target = 40, Icon = "🛒" },
	BuyEpic = { Target = 5, Icon = "✨", MinRarity = "Epic" },
	BuyLegendary = { Target = 1, Icon = "🌟", MinRarity = "Legendary" },
	NightOutside = { Target = 300, Icon = "🌙" },
	Earn = { Icon = "🪙" }, -- objectif calculé : environ 3 h de revenus
	Sell = { Target = 20, Icon = "💰" },
}
Missions.WeeklyPool = { "Steal", "Bonk", "Trap", "Buy", "BuyEpic", "BuyLegendary", "NightOutside", "Earn", "Sell" }
Missions.WeeklyReward = { Minutes = 45, Min = 5000 }
Missions.WeeklyBonusGhost = { Rarity = "Epic", Mutation = "Gold" }

local WEEK = 7 * 86400
local MONDAY_OFFSET = 4 * 86400 -- le 1er janvier 1970 était un jeudi

-- Numéro de la semaine (elle commence le lundi à 0h UTC)
function Missions.thisWeek(t: number): number
	return (t - MONDAY_OFFSET) // WEEK
end

-- Début de la semaine suivante (temps Unix)
function Missions.weekEnd(week: number): number
	return (week + 1) * WEEK + MONDAY_OFFSET
end

function Missions.weeklyReward(incomePerSecond: number): number
	local r = Missions.WeeklyReward
	return math.max(r.Min, math.floor(incomePerSecond * 60 * r.Minutes))
end

function Missions.weeklyEarnTarget(incomePerSecond: number): number
	return math.max(50000, math.floor(incomePerSecond * 3 * 3600))
end

-- Les 3 défis d'un joueur pour une semaine (toujours les mêmes, tous différents)
function Missions.generateWeekly(week: number, userId: number, incomePerSecond: number)
	local seed = (week * 104729 + math.abs(userId) * 31) % 2147483647
	local function nextRandom(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local pool = table.clone(Missions.WeeklyPool)
	local list = {}
	for _ = 1, 3 do
		local id = table.remove(pool, math.floor(nextRandom() * #pool) + 1)
		local target = Missions.WeeklyDefs[id].Target or Missions.weeklyEarnTarget(incomePerSecond)
		table.insert(list, { Id = id, Tier = "weekly", Target = target, Progress = 0, Done = false })
	end
	return list
end

-- Tire les 3 missions d'un joueur pour un jour donné (toujours les mêmes pour ce jour)
function Missions.generate(day: number, userId: number, incomePerSecond: number)
	local seed = (day * 7919 + math.abs(userId)) % 2147483647
	local function nextRandom(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local list = {}
	for _, tier in Missions.Tiers do
		local pool = Missions.Pool[tier]
		local id = pool[math.floor(nextRandom() * #pool) + 1]
		local target = Missions.Defs[id].Target or Missions.earnTarget(incomePerSecond)
		table.insert(list, { Id = id, Tier = tier, Target = target, Progress = 0, Done = false })
	end
	return list
end

return Missions
