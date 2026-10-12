-- Exporte la géométrie des 32 fantômes en JSON (pour tools/preview_ghosts.py)
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local Loader = require("../tests/loader")
local GhostData = Loader.loadModule("src/ReplicatedStorage/Shared/GhostData.luau")
local GhostFactory = Loader.loadModule("src/ReplicatedStorage/Shared/GhostFactory.luau")

local out = {}
local keys = {}
for _, ghost in GhostData.List do
	table.insert(keys, ghost.Id)
end
-- quelques variantes pour l'aperçu
for _, key in { "DrapMou#Gold", "Caquetome#Rainbow", "DJBouhBoum#Gold", "MegaBouhCosmique#Rainbow" } do
	table.insert(keys, key)
end
for _, key in keys do
	local ghost = GhostData.get(key)
	local model = GhostFactory.build(key)
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
	local mutation = GhostData.mutationOf(key)
	local name = ghost.Name.fr .. (if mutation then " " .. mutation.Name.fr else "")
	table.insert(out, { id = key, name = name, rarity = ghost.Rarity, parts = parts })
end
local path = process.args[1] or "ghosts.json"
fs.writeFile(path, serde.encode("json", out))
print("Exporté : " .. path)
