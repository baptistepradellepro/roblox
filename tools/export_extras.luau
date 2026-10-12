-- Exporte la géométrie des monstres, des armes et de la roue en JSON
-- (même format que export_ghosts.luau, pour tools/preview_ghosts.py)
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local Loader = require("../tests/loader")
local Monsters = Loader.loadModule("src/ReplicatedStorage/Shared/Monsters.luau")
local Weapons = Loader.loadModule("src/ReplicatedStorage/Shared/Weapons.luau")
local Wheel = Loader.loadModule("src/ReplicatedStorage/Shared/Wheel.luau")

local function export(model, id: string, name: string, rarity: string)
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local shape = if d:IsA("WedgePart") then "Wedge" else d.Shape.Name
			table.insert(parts, {
				shape = shape,
				size = { d.Size.X, d.Size.Y, d.Size.Z },
				cf = { d.CFrame:GetComponents() },
				color = { d.Color.R, d.Color.G, d.Color.B },
				transparency = d.Transparency,
				neon = d.Material.Name == "Neon",
			})
		end
	end
	return { id = id, name = name, rarity = rarity, parts = parts }
end

local out = {}
for _, monster in Monsters.List do
	table.insert(out, export(Monsters.build(monster.Id), monster.Id, monster.Name.fr, "Halloween"))
end
for _, weapon in Weapons.List do
	local tool = Weapons.buildTool(weapon.Id)
	table.insert(out, export(tool, weapon.Id, weapon.Name.fr, "Epic"))
end
table.insert(out, export(Wheel.build(nil), "Wheel", "Roue de la Fortune", "Legendary"))
local path = process.args[1] or "extras.json"
fs.writeFile(path, serde.encode("json", out))
print("Exporté : " .. path)
