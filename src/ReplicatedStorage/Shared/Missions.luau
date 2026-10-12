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
