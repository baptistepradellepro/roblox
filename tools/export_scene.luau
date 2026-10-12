-- Exporte en JSON tous les modèles du jeu, pour tools/render_publication.py
-- (icône, miniatures et images de la boutique faites avec les vrais modèles).
-- Usage : lune run tools/export_scene.luau scene.json
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame

local Loader = require("../tests/loader")
local GhostData = Loader.loadModule("src/ReplicatedStorage/Shared/GhostData.luau")
local GhostFactory = Loader.loadModule("src/ReplicatedStorage/Shared/GhostFactory.luau")
local MapBuilder = Loader.loadModule("src/ServerScriptService/Services/MapBuilder.luau")
local Monsters = Loader.loadModule("src/ReplicatedStorage/Shared/Monsters.luau")
local Traps = Loader.loadModule("src/ReplicatedStorage/Shared/Traps.luau")
local Weapons = Loader.loadModule("src/ReplicatedStorage/Shared/Weapons.luau")
local Wheel = Loader.loadModule("src/ReplicatedStorage/Shared/Wheel.luau")

local function partsOf(model): { any }
	local parts = {}
	local list = model:GetDescendants()
	if model:IsA("BasePart") then
		table.insert(list, model)
	end
	for _, d in list do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(parts, {
				name = d.Name,
				shape = if d:IsA("WedgePart") then "Wedge" else d.Shape.Name,
				size = { d.Size.X, d.Size.Y, d.Size.Z },
				cf = { d.CFrame:GetComponents() },
				color = { d.Color.R, d.Color.G, d.Color.B },
				transparency = d.Transparency,
				neon = d.Material.Name == "Neon",
			})
		end
	end
	return parts
end

local out = { ghosts = {}, monsters = {}, weapons = {}, traps = {}, pedestals = {} }

for _, ghost in GhostData.List do
	local keys = { ghost.Id }
	for _, mutation in GhostData.MutationOrder do
		table.insert(keys, GhostData.key(ghost.Id, mutation))
	end
	for _, key in keys do
		local model = GhostFactory.build(key)
		out.ghosts[key] = {
			rarity = ghost.Rarity,
			name = ghost.Name,
			bottom = model:GetAttribute("Bottom") or 2,
			top = model:GetAttribute("Top") or 2,
			parts = partsOf(model),
		}
	end
end

for _, monster in Monsters.List do
	out.monsters[monster.Id] = { name = monster.Name, parts = partsOf(Monsters.build(monster.Id)) }
end
for _, weapon in Weapons.List do
	out.weapons[weapon.Id] = { name = weapon.Name, parts = partsOf(Weapons.buildTool(weapon.Id)) }
end
for _, trap in Traps.List do
	out.traps[trap.Id] = { name = trap.Name, parts = partsOf(Traps.build(trap.Id, CFrame.identity)) }
end
out.wheel = { parts = partsOf(Wheel.build(nil)) }

-- La carte entière (sans les fantômes, posés ensuite par le script de rendu)
local map = MapBuilder.build()
out.map = partsOf(map)
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") and d:GetAttribute("GhostCFrame") then
		table.insert(out.pedestals, {
			base = d:GetAttribute("BaseIndex"),
			slot = d:GetAttribute("Slot"),
			cf = { d:GetAttribute("GhostCFrame"):GetComponents() },
		})
	elseif d.Name == "FortuneWheelAnchor" then
		out.wheelAnchor = { d.CFrame:GetComponents() }
	end
end
for _, base in map:FindFirstChild("Bases"):GetChildren() do
	out.origins = out.origins or {}
	out.origins[base.Name] = { base:GetAttribute("Origin"):GetComponents() }
end

local path = process.args[1] or "scene.json"
fs.writeFile(path, serde.encode("json", out))
print("Exporté : " .. path)
