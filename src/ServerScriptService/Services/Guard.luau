--[[
	Guard : petites vérifications anti-triche utilisées par tous les services.
	- rate()  : empêche un joueur d'envoyer une demande trop souvent
	- isInt() : vérifie qu'une valeur envoyée par le client est un entier valide
	- root()  : renvoie le HumanoidRootPart d'un joueur vivant (ou nil)
	- safely(): lance une fonction sans que son erreur arrête la boucle qui l'appelle
]]

local Guard = {}

local lastCall: { [Player]: { [string]: number } } = {}

-- true si le joueur a le droit d'agir (pas plus d'une fois toutes les "interval" secondes)
function Guard.rate(player: Player, key: string, interval: number): boolean
	local now = os.clock()
	local calls = lastCall[player]
	if not calls then
		calls = {}
		lastCall[player] = calls
	end
	local last = calls[key]
	if last and now - last < interval then
		return false
	end
	calls[key] = now
	return true
end

function Guard.clear(player: Player)
	lastCall[player] = nil
end

function Guard.isInt(value: any, min: number, max: number): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= min and value <= max
end

function Guard.root(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Lance fn(...) sans laisser une erreur arrêter la boucle qui l'appelle.
-- L'erreur est affichée dans la Sortie (une fois toutes les 30 s au plus par boucle).
local lastWarn: { [string]: number } = {}
function Guard.safely(label: string, fn: (...any) -> ...any, ...: any): boolean
	local ok, err = pcall(fn, ...)
	if not ok then
		local t = os.clock()
		if not lastWarn[label] or t - lastWarn[label] > 30 then
			lastWarn[label] = t
			warn("[" .. label .. "] erreur, le jeu continue : " .. tostring(err))
		end
	end
	return ok
end

function Guard.humanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

return Guard
