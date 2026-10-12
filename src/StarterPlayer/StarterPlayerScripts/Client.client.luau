--[[
	Client : le point de départ côté joueur. Il démarre chaque "contrôleur"
	(interface, affichage des fantômes, effets...) dans le bon ordre.
]]

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local Controllers = script.Parent:WaitForChild("Controllers")

-- On attend que le serveur ait préparé le joueur (données chargées, base attribuée)
if not player:GetAttribute("Ready") then
	player:GetAttributeChangedSignal("Ready"):Wait()
end

local ORDER = {
	"Effects",
	"HUD",
	"Announce",
	"PathView",
	"BaseView",
	"CarryView",
}

for _, name in ORDER do
	local module = require(Controllers:WaitForChild(name)) :: any
	if module.start then
		task.spawn(function()
			local ok, err = pcall(module.start)
			if not ok then
				warn("[Client] Erreur au démarrage de " .. name .. " : " .. tostring(err))
			end
		end)
	end
end
