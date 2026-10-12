--[[
	Hooks : un petit "panneau d'affichage" d'événements entre services.
	Un service annonce qu'il s'est passé quelque chose (Hooks.fire("Steal", joueur)),
	et ceux que ça intéresse l'écoutent (Hooks.on("Steal", ...)), sans dépendre les uns
	des autres. Utilisé par les missions du jour.

	Événements : Buy (joueur, fantôme), Sell, Steal, Bonk, Lock, Earn (joueur, pièces),
	NightOutside (joueur, secondes passées dehors pendant la nuit), Trap (propriétaire
	dont un piège a attrapé quelqu'un), Rebirth (joueur, nombre de rebirths),
	Discover (joueur, fantôme nouveau dans le Fantômédex), IndexComplete (joueur),
	WeeklyBonus (joueur qui a fini les 3 défis de la semaine)
]]

local Hooks = {}

local listeners: { [string]: { (...any) -> () } } = {}

function Hooks.on(name: string, callback: (...any) -> ())
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], callback)
end

function Hooks.fire(name: string, ...: any)
	for _, callback in listeners[name] or {} do
		task.spawn(callback, ...)
	end
end

return Hooks
