--[[
	Lang : choisit la langue du joueur (français si son Roblox est en français,
	sinon anglais) et traduit les textes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GhostData = require(Shared:WaitForChild("GhostData"))
local Monsters = require(Shared:WaitForChild("Monsters"))
local Strings = require(Shared:WaitForChild("Strings"))
local Weapons = require(Shared:WaitForChild("Weapons"))

local Lang = {}

local function detect(): string
	if Config.ForceLanguage == "fr" or Config.ForceLanguage == "en" then
		return Config.ForceLanguage
	end
	local ok, locale = pcall(function()
		return Players.LocalPlayer.LocaleId
	end)
	if ok and type(locale) == "string" and string.sub(string.lower(locale), 1, 2) == "fr" then
		return "fr"
	end
	return "en"
end

Lang.code = detect()

-- Roblox peut traduire automatiquement l'anglais vers d'autres langues (espagnol,
-- portugais...). On le désactive pour le français, déjà traduit à la main.
Lang.autoLocalize = Lang.code ~= "fr"

-- "DrapMou#Gold" -> "Drap Mou Doré" (fr) / "Golden Floppy Sheet" (en)
function Lang.ghostName(ghostKey: string): string
	local ghost = GhostData.get(ghostKey)
	if not ghost then
		return tostring(ghostKey)
	end
	local name = ghost.Name[Lang.code] or ghost.Name.en
	local mutation = GhostData.mutationOf(ghostKey)
	if mutation then
		local tag = mutation.Name[Lang.code] or mutation.Name.en
		return if Lang.code == "fr" then name .. " " .. tag else tag .. " " .. name
	end
	return name
end

function Lang.ghostGag(ghostId: string): string
	local ghost = GhostData.get(ghostId)
	if not ghost then
		return ""
	end
	return ghost.Gag[Lang.code] or ghost.Gag.en
end

-- Choisit le texte dans la bonne langue : { fr = "...", en = "..." }
function Lang.pick(texts: { [string]: string }?): string
	if not texts then
		return ""
	end
	return texts[Lang.code] or texts.en or ""
end

function Lang.monsterName(id: string): string
	local monster = Monsters.get(id)
	return if monster then Lang.pick(monster.Name) else tostring(id)
end

function Lang.weaponName(id: string): string
	local weapon = Weapons.get(id)
	return if weapon then Lang.pick(weapon.Name) else tostring(id)
end

function Lang.rarityName(rarity: string): string
	return Strings.format(Lang.code, "Rarity_" .. rarity)
end

-- Traduit une clé. Les paramètres "ghost" (Id) et "rarity" sont traduits aussi.
function Lang.t(key: string, params: { [string]: any }?): string
	local resolved = nil
	if params then
		resolved = {}
		for name, value in params do
			if name == "ghost" then
				resolved[name] = Lang.ghostName(value)
			elseif name == "rarity" then
				resolved[name] = Lang.rarityName(value)
			elseif name == "monster" then
				resolved[name] = Lang.monsterName(value)
			elseif name == "weapon" then
				resolved[name] = Lang.weaponName(value)
			else
				resolved[name] = value
			end
		end
	end
	return Strings.format(Lang.code, key, resolved)
end

return Lang
