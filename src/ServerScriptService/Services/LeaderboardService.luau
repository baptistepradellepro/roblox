--[[
	LeaderboardService : le tableau des "plus grands voleurs de la semaine".
	  - chaque vol réussi ajoute +1 au voleur dans un classement Roblox partagé par
	    tous les serveurs (OrderedDataStore), remis à zéro chaque lundi 00h UTC
	  - toutes les minutes : on envoie les nouveaux vols et on relit le top 10
	  - le top 10 est publié dans un attribut de ReplicatedStorage, et chaque joueur
	    l'affiche sur le grand écran au-dessus du chemin
	Sans accès aux API (Studio), le tableau montre les vols de la partie en cours.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Guard = require(script.Parent.Guard)

local LeaderboardService = {}

local REFRESH = 60
local WEEK = 7 * 86400
local MONDAY_OFFSET = 4 * 86400 -- le 1er janvier 1970 était un jeudi

local pending: { [number]: number } = {} -- vols pas encore envoyés
local session: { [number]: number } = {} -- vols de cette partie (secours sans API)
local names: { [number]: string } = {}

function LeaderboardService.weekNumber(t: number?): number
	return ((t or os.time()) - MONDAY_OFFSET) // WEEK
end

function LeaderboardService.weekEndsAt(t: number?): number
	return (LeaderboardService.weekNumber(t) + 1) * WEEK + MONDAY_OFFSET
end

local function orderedStore(): OrderedDataStore?
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore("WeeklySteals_" .. LeaderboardService.weekNumber())
	end)
	return if ok then result else nil
end

function LeaderboardService.recordSteal(player: Player)
	local id = player.UserId
	names[id] = player.DisplayName
	pending[id] = (pending[id] or 0) + 1
	session[id] = (session[id] or 0) + 1
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = if ok and result then result else "?"
	names[userId] = name
	return name
end

local function publish(list)
	ReplicatedStorage:SetAttribute("LeaderboardData", HttpService:JSONEncode(list))
	ReplicatedStorage:SetAttribute("LeaderboardResetAt", LeaderboardService.weekEndsAt())
end

-- Classement de secours : les vols de cette partie
local function sessionTop()
	local list = {}
	for userId, count in session do
		table.insert(list, { Name = nameOf(userId), Value = count, UserId = userId })
	end
	table.sort(list, function(a, b)
		return a.Value > b.Value
	end)
	while #list > 10 do
		table.remove(list)
	end
	return list
end

function LeaderboardService.refresh()
	local store = orderedStore()
	-- 1. on envoie les nouveaux vols
	if store then
		local ods = store :: OrderedDataStore
		for userId, count in pending do
			local ok = pcall(function()
				ods:IncrementAsync(tostring(userId), count)
			end)
			if ok then
				pending[userId] = nil
			end
		end
	end
	-- 2. on relit le top 10
	local list = nil
	if store then
		local ods = store :: OrderedDataStore
		local ok, page = pcall(function()
			return ods:GetSortedAsync(false, 10):GetCurrentPage()
		end)
		if ok and page then
			list = {}
			for _, entry in page do
				local userId = tonumber(entry.key) or 0
				table.insert(list, { Name = nameOf(userId), Value = entry.value, UserId = userId })
			end
		end
	end
	publish(list or sessionTop())
end

function LeaderboardService.start()
	publish({})
	task.spawn(function()
		task.wait(5)
		while true do
			Guard.safely("Leaderboard", LeaderboardService.refresh)
			task.wait(REFRESH)
		end
	end)
end

return LeaderboardService
